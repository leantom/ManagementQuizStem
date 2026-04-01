//
//  AuthSessionController.swift
//  ManagementQuizStem
//
//  Created by Codex on 01/04/26.
//

import Foundation
import FirebaseAuth
import FirebaseCore
import SwiftUI

private struct AdminAccessConfiguration {
    static let allowedEmailsKey = "ADMIN_ALLOWED_EMAILS"

    let allowedEmails: Set<String>

    static func current(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> AdminAccessConfiguration {
        let rawValue =
            processInfo.environment[allowedEmailsKey] ??
            (bundle.object(forInfoDictionaryKey: allowedEmailsKey) as? String) ??
            ""

        return AdminAccessConfiguration(
            allowedEmails: Set(parseEmailList(from: rawValue))
        )
    }

    var hasRestrictions: Bool {
        allowedEmails.isEmpty == false
    }

    func allows(email: String?) -> Bool {
        guard let normalizedEmail = Self.normalized(email) else {
            return false
        }

        return allowedEmails.isEmpty || allowedEmails.contains(normalizedEmail)
    }

    static func normalized(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }

        let email = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return email.isEmpty ? nil : email
    }

    private static func parseEmailList(from rawValue: String) -> [String] {
        rawValue
            .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .compactMap(normalized)
    }
}

@MainActor
final class AuthSessionController: ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var isLoading = true
    @Published private(set) var isAuthenticating = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var currentUserEmail: String?

    private var hasStarted = false
    private var authListenerHandle: AuthStateDidChangeListenerHandle?
    private var preparedUserID: String?
    private let accessConfiguration = AdminAccessConfiguration.current()

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        isLoading = true

        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }
                self.handleAuthStateChange(user, source: "listener")
            }
        }

        if let currentUser = Auth.auth().currentUser {
            handleAuthStateChange(currentUser, source: "cached")
        } else {
            isLoading = false
        }
    }

    func signIn(email: String, password: String) {
        let normalizedEmail = AdminAccessConfiguration.normalized(email)

        guard let normalizedEmail else {
            errorMessage = "Enter a valid admin email."
            return
        }

        guard password.isEmpty == false else {
            errorMessage = "Enter your password."
            return
        }

        isAuthenticating = true
        isLoading = false
        errorMessage = nil

        Auth.auth().signIn(withEmail: normalizedEmail, password: password) { [weak self] authResult, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    self.errorMessage = "Sign-in failed: \(error.localizedDescription)"
                    self.isReady = false
                    self.isAuthenticating = false
                    return
                }

                guard let user = authResult?.user else {
                    self.errorMessage = "Sign-in failed: Missing Firebase user."
                    self.isReady = false
                    self.isAuthenticating = false
                    return
                }

                self.handleAuthStateChange(user, source: "email-password")
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            resetSessionState(clearError: true)
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
        }
    }

    var environment: FirebaseEnvironment {
        FirebaseEnvironment.current()
    }

    var environmentLabel: String {
        switch environment {
        case .dev:
            return "Development"
        case .beta:
            return "Beta"
        case .prod:
            return "Production"
        }
    }

    var environmentDatabaseID: String {
        environment.firestoreDatabaseID()
    }

    var environmentTint: Color {
        switch environment {
        case .dev:
            return Color(red: 0.14, green: 0.47, blue: 0.91)
        case .beta:
            return Color(red: 0.22, green: 0.58, blue: 0.44)
        case .prod:
            return Color(red: 0.84, green: 0.22, blue: 0.30)
        }
    }

    var firebaseProjectID: String {
        FirebaseApp.app()?.options.projectID ?? "unknown"
    }

    var accessPolicyTitle: String {
        accessConfiguration.hasRestrictions ? "Allowlisted Admin Access" : "Open Admin Access"
    }

    var accessPolicySummary: String {
        if accessConfiguration.hasRestrictions {
            let count = accessConfiguration.allowedEmails.count
            return count == 1
                ? "Restricted to 1 configured admin email."
                : "Restricted to \(count) configured admin emails."
        }

        return "No email allowlist configured."
    }

    var accessPolicyDescription: String {
        if accessConfiguration.hasRestrictions {
            return "Use a configured Firebase email/password admin account to continue."
        }

        return "Any Firebase email/password admin account can request access in this build."
    }

    private func handleAuthStateChange(_ user: User?, source: String) {
        guard let user else {
            resetSessionState(clearError: false)
            return
        }

        if user.isAnonymous {
            invalidateCurrentUser(message: nil)
            return
        }

        guard accessConfiguration.allows(email: user.email) else {
            invalidateCurrentUser(message: "This account is not allowed to access the admin app.")
            return
        }

        print("User already signed in: \(user.uid)")
        prepareSession(for: user, source: source)
    }

    private func prepareSession(for user: User, source: String) {
        guard preparedUserID != user.uid else { return }

        preparedUserID = user.uid
        isReady = false
        isLoading = true
        isAuthenticating = source == "email-password"
        errorMessage = nil
        currentUserEmail = user.email

        user.getIDTokenResult(forcingRefresh: false) { [weak self] _, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    self.preparedUserID = nil
                    self.errorMessage = "Failed to prepare Firebase session: \(error.localizedDescription)"
                    self.isReady = false
                    self.isLoading = false
                    self.isAuthenticating = false
                    return
                }

                self.isReady = true
                self.isLoading = false
                self.isAuthenticating = false
                self.errorMessage = nil
                print("Firebase auth ready (\(source)): \(user.uid)")
            }
        }
    }

    private func invalidateCurrentUser(message: String?) {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = "Failed to sign out invalid session: \(error.localizedDescription)"
            isReady = false
            isLoading = false
            isAuthenticating = false
            currentUserEmail = nil
            preparedUserID = nil
            return
        }

        resetSessionState(clearError: message == nil)
        if let message {
            errorMessage = message
        }
    }

    private func resetSessionState(clearError: Bool) {
        preparedUserID = nil
        currentUserEmail = nil
        isReady = false
        isLoading = false
        isAuthenticating = false

        if clearError {
            errorMessage = nil
        }
    }

    deinit {
        if let authListenerHandle {
            Auth.auth().removeStateDidChangeListener(authListenerHandle)
        }
    }
}
