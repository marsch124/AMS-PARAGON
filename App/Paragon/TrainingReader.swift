import Foundation
import Security
import ParagonCore

// Build 369: the "Training:" line on Today. The RULES are in Core (`TrainingToday`, tested). This file only
// READS the small note AMS Triathlon Training keeps in the keychain; it never writes or deletes it.

protocol TrainingSource: Sendable {
    func read() -> Data?
}

/// The real thing: one generic-password item in the group Triathlon Training writes to. Read only.
struct KeychainTraining: TrainingSource {
    func read() -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: TrainingToday.service,
                                    kSecAttrAccount as String: TrainingToday.account,
                                    kSecAttrAccessGroup as String: TrainingToday.group,
                                    kSecUseDataProtectionKeychain as String: true,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }
}

/// Tests, the sample and pictures: fixed bytes, nothing from the keychain.
struct MemoryTraining: TrainingSource {
    var data: Data? = nil
    func read() -> Data? { data }
}

enum TrainingReader {
    /// Passed beside `-paragon-test-vault`: the memory source holds a made-up note for today (pictures).
    static let sampleArgument = "-paragon-training-sample"

    /// 🚨 A test-vault, sample or screen-test run gets the memory source and never the real keychain.
    static func make() -> TrainingSource {
        #if DEBUG
        if TestVault.isWanted {
            if ProcessInfo.processInfo.arguments.contains(sampleArgument) {
                return MemoryTraining(data: sampleNote())
            }
            return MemoryTraining()
        }
        #endif
        return KeychainTraining()
    }

    #if DEBUG
    /// One made-up session for today's local date, written now.
    static func sampleNote(today: DateOnly = .today(), now: Date = Date()) -> Data {
        let json = """
        {"v":1,"day":"\(today.description)","written":"\(ISO8601DateFormatter().string(from: now))",
         "sessions":[{"key":"sample-run","sport":"run","sportWord":"Run","title":"Easy run","minutes":45,
                      "length":"45 min","state":"todo","open":"amsworkoutsync://session/sample-run"}]}
        """
        return Data(json.utf8)
    }
    #endif
}
