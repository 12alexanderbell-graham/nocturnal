import Foundation
import Security

/// The pairing lives in the Keychain, readable only on this device after its first unlock, and never in backups
/// that leave it: whoever has the key can control the computer.
///
/// It's kept in the shared keychain group (the first entry of keychain-access-groups in both the app's and the
/// widgets' entitlements, so items land there without naming it), which lets the widgets' buttons reach the computer.
nonisolated enum PairingStore {
    private static let service = "tools.nocturnal.pairing"
    private static let account = "computer"

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    static func load() -> Pairing? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess, let data = item as? Data,
              let saved = try? JSONDecoder().decode(Saved.self, from: data),
              let key = Base64URL.decode(saved.key) else { return nil }
        return Pairing(key: key, server: saved.server)
    }

    /// Saving again moves a pairing made by an earlier version (kept in the app's own group) into the shared one.
    @discardableResult
    static func save(_ p: Pairing) -> Bool {
        guard let data = try? JSONEncoder().encode(Saved(key: Base64URL.encode(p.key), server: p.server)) else { return false }
        SecItemDelete(query as CFDictionary)
        var q = query
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }

    private struct Saved: Codable {
        var key: String
        var server: String
    }
}
