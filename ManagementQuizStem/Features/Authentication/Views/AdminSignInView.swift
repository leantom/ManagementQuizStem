//
//  AdminSignInView.swift
//  ManagementQuizStem
//
//  Created by Codex on 01/04/26.
//

import SwiftUI

private enum AdminSignInField: Hashable {
    case email
    case password
}

struct AdminSignInView: View {
    @EnvironmentObject private var authSession: AuthSessionController
    @FocusState private var focusedField: AdminSignInField?

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        AdminAuthScaffold {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Admin Sign-In")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(.secondary)

                        Text("Authenticate to continue")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(AdminPalette.ink)
                    }

                    Spacer(minLength: 16)

                    AdminStatusPill(
                        title: authSession.environmentLabel,
                        icon: "bolt.horizontal.circle.fill",
                        tint: authSession.environmentTint
                    )
                }

                Text("Use your Firebase email/password credentials to access the internal content management workspace.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AdminPalette.subtleInk)
                    .fixedSize(horizontal: false, vertical: true)

                AdminInlineInfoCard(
                    icon: "checkmark.shield.fill",
                    title: authSession.accessPolicyTitle,
                    message: authSession.accessPolicyDescription,
                    tint: authSession.environmentTint
                )

                VStack(alignment: .leading, spacing: 16) {
                    AdminInputField(
                        title: "Admin email",
                        placeholder: "name@company.com",
                        text: $email
                    )
                    .focused($focusedField, equals: .email)

                    AdminSecureInputField(
                        title: "Password",
                        placeholder: "Enter password",
                        text: $password
                    )
                    .focused($focusedField, equals: .password)
                }

                if let errorMessage = authSession.errorMessage {
                    AdminInlineInfoCard(
                        icon: "exclamationmark.triangle.fill",
                        title: "Unable to sign in",
                        message: errorMessage,
                        tint: AdminPalette.danger
                    )
                }

                Button(action: signIn) {
                    HStack(spacing: 10) {
                        if authSession.isAuthenticating {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }

                        Text(authSession.isAuthenticating ? "Authorizing..." : "Continue to Admin Console")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(authSession.environmentTint.gradient)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.7)

                Divider()
                    .overlay(AdminPalette.stroke.opacity(0.8))

                VStack(alignment: .leading, spacing: 12) {
                    AdminMetaRow(
                        title: "Firebase project",
                        value: authSession.firebaseProjectID
                    )
                    AdminMetaRow(
                        title: "Firestore database",
                        value: authSession.environmentDatabaseID
                    )
                    AdminMetaRow(
                        title: "Access scope",
                        value: authSession.accessPolicySummary
                    )
                }
            }
            .frame(maxWidth: 440, alignment: .leading)
        }
        .onAppear {
            if email.isEmpty, let currentUserEmail = authSession.currentUserEmail {
                email = currentUserEmail
            }

            focusedField = .email
        }
        .onSubmit(signIn)
    }

    private var canSubmit: Bool {
        email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        password.isEmpty == false &&
        authSession.isAuthenticating == false
    }

    private func signIn() {
        authSession.signIn(email: email, password: password)
    }
}

struct AdminAuthLoadingView: View {
    @EnvironmentObject private var authSession: AuthSessionController

    var body: some View {
        AdminAuthScaffold {
            VStack(alignment: .leading, spacing: 24) {
                Text("Preparing admin session")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(AdminPalette.ink)

                Text(
                    authSession.currentUserEmail == nil
                        ? "Checking for an authorized Firebase session and loading the active admin environment."
                        : "Refreshing credentials for \(authSession.currentUserEmail ?? "the current admin") before opening the console."
                )
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(AdminPalette.subtleInk)
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(authSession.environmentTint)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Secure session check in progress")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(AdminPalette.ink)

                        Text("\(authSession.environmentLabel) • \(authSession.environmentDatabaseID)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AdminPalette.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AdminPalette.stroke, lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 12) {
                    AdminMetaRow(
                        title: "Firebase project",
                        value: authSession.firebaseProjectID
                    )
                    AdminMetaRow(
                        title: "Access scope",
                        value: authSession.accessPolicySummary
                    )
                }
            }
            .frame(maxWidth: 440, alignment: .leading)
        }
    }
}

private struct AdminAuthScaffold<Panel: View>: View {
    @EnvironmentObject private var authSession: AuthSessionController

    @ViewBuilder let panel: () -> Panel

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 1040
            let horizontalPadding = min(max(32, geometry.size.width * 0.06), 84)

            ZStack {
                AdminAuthBackground(tint: authSession.environmentTint)

                ScrollView(.vertical, showsIndicators: false) {
                    Group {
                        if isCompact {
                            VStack(alignment: .leading, spacing: 32) {
                                heroPanel(titleSize: 40)
                                panel()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            HStack(alignment: .center, spacing: 72) {
                                heroPanel(titleSize: 54)
                                    .frame(maxWidth: 520, alignment: .leading)

                                panel()
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 48)
                    .frame(maxWidth: 1280, minHeight: geometry.size.height)
                }
            }
        }
    }

    private func heroPanel(titleSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(authSession.environmentTint.opacity(0.14))

                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(authSession.environmentTint)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text("ManagementQuizStem")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text("Admin CMS")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(AdminPalette.ink)
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Review the active environment before you change quiz content.")
                    .font(.system(size: titleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(AdminPalette.ink)

                Text("This internal workspace signs admins into Firebase first, then opens the content shell for topics, imports, challenges, badges, and maintenance tools.")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(AdminPalette.subtleInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                AdminStatusPill(
                    title: authSession.environmentLabel,
                    icon: "bolt.horizontal.circle.fill",
                    tint: authSession.environmentTint
                )

                AdminStatusPill(
                    title: authSession.accessPolicyTitle,
                    icon: "lock.shield.fill",
                    tint: AdminPalette.ink
                )
            }

            VStack(spacing: 14) {
                AdminContextCard(
                    title: "Environment",
                    value: authSession.environmentLabel,
                    detail: "Firestore \(authSession.environmentDatabaseID)",
                    tint: authSession.environmentTint
                )

                AdminContextCard(
                    title: "Firebase Project",
                    value: authSession.firebaseProjectID,
                    detail: "Email and password authentication",
                    tint: AdminPalette.ink
                )

                AdminContextCard(
                    title: "Access Policy",
                    value: authSession.accessPolicySummary,
                    detail: "Only authorized admins should continue past sign-in.",
                    tint: AdminPalette.ink
                )
            }

            Text("Authorized operators only. Imports, destructive tools, and live content edits will run against the environment shown here.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AdminAuthBackground: View {
    let tint: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white,
                    AdminPalette.canvas,
                    AdminPalette.canvas.opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(tint.opacity(0.14))
                .frame(width: 440, height: 440)
                .blur(radius: 26)
                .offset(x: -260, y: -220)

            Circle()
                .fill(AdminPalette.deepBlue.opacity(0.10))
                .frame(width: 320, height: 320)
                .blur(radius: 22)
                .offset(x: 300, y: 180)

            RoundedRectangle(cornerRadius: 42, style: .continuous)
                .fill(Color.white.opacity(0.45))
                .frame(width: 520, height: 520)
                .blur(radius: 40)
                .offset(x: 340, y: -260)
        }
        .ignoresSafeArea()
    }
}

private struct AdminContextCard: View {
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AdminPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AdminPalette.subtleInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AdminPalette.surface.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct AdminInlineInfoCard: View {
    let icon: String
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(tint.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AdminPalette.ink)

                Text(message)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AdminPalette.subtleInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AdminPalette.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct AdminStatusPill: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        Label {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        } icon: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.84))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct AdminInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AdminPalette.ink)

            TextField("", text: $text, prompt: Text(placeholder))
                .textFieldStyle(.plain)
                .foregroundStyle(.black)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AdminPalette.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AdminPalette.stroke, lineWidth: 1)
                )
        }
    }
}

private struct AdminSecureInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AdminPalette.ink)

            SecureField("", text: $text, prompt: Text(placeholder))
                .textFieldStyle(.plain)
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AdminPalette.surfaceElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AdminPalette.stroke, lineWidth: 1)
                )
        }
    }
}

private struct AdminMetaRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 124, alignment: .leading)

            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AdminPalette.subtleInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private enum AdminPalette {
    static let canvas = Color(red: 0.95, green: 0.96, blue: 0.99)
    static let surface = Color.white
    static let surfaceElevated = Color(red: 0.975, green: 0.978, blue: 0.995)
    static let ink = Color(red: 0.08, green: 0.12, blue: 0.19)
    static let subtleInk = Color(red: 0.28, green: 0.33, blue: 0.42)
    static let deepBlue = Color(red: 0.12, green: 0.22, blue: 0.49)
    static let stroke = Color(red: 0.84, green: 0.87, blue: 0.92)
    static let danger = Color(red: 0.82, green: 0.21, blue: 0.27)
}

#Preview {
    AdminSignInView()
        .environmentObject(AuthSessionController())
}
