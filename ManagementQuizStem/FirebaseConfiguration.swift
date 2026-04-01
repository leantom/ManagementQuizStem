//
//  FirebaseConfiguration.swift
//  ManagementQuizStem
//
//  Created by Codex on 01/04/26.
//

import Foundation
import FirebaseCore

enum FirebaseEnvironment: String {
    case dev
    case beta
    case prod

    static let infoKey = "FIREBASE_ENV"

    static func current(in bundle: Bundle = .main) -> FirebaseEnvironment {
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
}

enum FirebaseConfigurator {
    static func configure(bundle: Bundle = .main) {
        guard FirebaseApp.app() == nil else { return }

        let environment = FirebaseEnvironment.current(in: bundle)

        guard let options = loadOptions(for: environment, in: bundle) else {
            fatalError(
                "Missing Firebase plist for \(environment.rawValue). " +
                "Expected one of: \(environment.candidatePlistNames.map { "\($0).plist" }.joined(separator: ", "))"
            )
        }

        FirebaseApp.configure(options: options)
        print("Firebase configured for environment: \(environment.rawValue)")
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
