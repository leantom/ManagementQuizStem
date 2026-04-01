//
//  FirebaseConfiguration.swift
//  ManagementQuizStem
//
//  Created by Codex on 01/04/26.
//

import Foundation
import FirebaseCore
import FirebaseFirestore

enum FirebaseEnvironment: String {
    case dev
    case beta
    case prod

    static let infoKey = "FIREBASE_ENV"
    private static let firestoreDatabaseInfoKey = "FIRESTORE_DATABASE_ID"

    static func current(in bundle: Bundle = .main) -> FirebaseEnvironment {
        if
            let runtimeValue = ProcessInfo.processInfo.environment[infoKey],
            let environment = FirebaseEnvironment(
                rawValue: runtimeValue
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
            )
        {
            return environment
        }

        if
            let configuredValue = bundle.object(forInfoDictionaryKey: infoKey) as? String,
            let environment = FirebaseEnvironment(
                rawValue: configuredValue
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
            )
        {
            return environment
        }

        #if DEBUG
        return .dev
        #else
        return .prod
        #endif
    }

    var candidatePlistNames: [String] {
        [
            "GoogleService-Info-\(rawValue)",
            "GoogleService-Info",
        ]
    }

    var defaultFirestoreDatabaseID: String {
        switch self {
        case .dev:
            return "(default)"
        case .beta:
            return "beta-stem-db"
        case .prod:
            return "prod-stem-db"
        }
    }

    func firestoreDatabaseID(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> String {
        if
            let runtimeValue = processInfo.environment[Self.firestoreDatabaseInfoKey],
            let databaseID = Self.normalizedDatabaseID(from: runtimeValue)
        {
            return databaseID
        }

        if
            let configuredValue = bundle.object(forInfoDictionaryKey: Self.firestoreDatabaseInfoKey) as? String,
            let databaseID = Self.normalizedDatabaseID(from: configuredValue)
        {
            return databaseID
        }

        return defaultFirestoreDatabaseID
    }

    private static func normalizedDatabaseID(from rawValue: String) -> String? {
        let databaseID = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return databaseID.isEmpty ? nil : databaseID
    }
}

enum FirebaseConfigurator {
    private static var hasConfigured = false

    static func configure(bundle: Bundle = .main) {
        guard hasConfigured == false else { return }

        let environment = FirebaseEnvironment.current(in: bundle)
        let databaseID = environment.firestoreDatabaseID(bundle: bundle)

        guard let options = loadOptions(for: environment, in: bundle) else {
            fatalError(
                "Missing Firebase plist for \(environment.rawValue). " +
                "Expected one of: \(environment.candidatePlistNames.map { "\($0).plist" }.joined(separator: ", "))"
            )
        }

        FirebaseApp.configure(options: options)
        hasConfigured = true

        let projectID = options.projectID ?? "unknown"
        print(
            "Firebase configured for environment: \(environment.rawValue) " +
            "(project: \(projectID), database: \(databaseID))"
        )
    }

    private static func loadOptions(
        for environment: FirebaseEnvironment,
        in bundle: Bundle
    ) -> FirebaseOptions? {
        for plistName in environment.candidatePlistNames {
            guard let filePath = bundle.path(forResource: plistName, ofType: "plist") else {
                continue
            }

            if let options = FirebaseOptions(contentsOfFile: filePath) {
                print("Loaded Firebase config from \(plistName).plist")
                return options
            }
        }

        return nil
    }
}

enum AppFirestore {
    static func database() -> Firestore {
        let environment = FirebaseEnvironment.current()
        let databaseID = environment.firestoreDatabaseID()

        guard let app = FirebaseApp.app() else {
            fatalError("FirebaseApp must be configured before using Firestore.")
        }

        if databaseID == "(default)" {
            return Firestore.firestore(app: app)
        }

        return Firestore.firestore(app: app, database: databaseID)
    }
}
