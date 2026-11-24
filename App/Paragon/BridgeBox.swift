import Foundation
import Security
import ParagonCore

// The keychain side of the bridge between Finance Steward and PARAGON (the contract is `EventBridge` in Core).
// 🚨 The same file lives in both apps (only the Core import differs). A test, sample or screen-test run gets
// `MemoryBridge` and never touches the real keychain, so made-up events and projects cannot reach the other app.

/// Where the lists and messages are kept: the shared keychain group, or memory for tests and pictures.
protocol BridgeStore: Sendable {
    func read(_ box: EventBridge.Box, _ key: String) -> Data?
    @discardableResult func write(_ data: Data, _ box: EventBridge.Box, _ key: String) -> Bool
    func keys(_ box: EventBridge.Box) -> [String]
    func delete(_ box: EventBridge.Box, _ key: String)
}

extension BridgeStore {
    func list<T: Decodable>(_ type: T.Type, _ box: EventBridge.Box) -> T? {
        EventBridge.decode(type, from: read(box, EventBridge.listKey))
    }
    @discardableResult func put<T: Encodable>(_ list: T, _ box: EventBridge.Box) -> Bool {
        guard let data = EventBridge.encode(list) else { return false }
        return write(data, box, EventBridge.listKey)
    }
    /// Leaves a message for the other app.
    @discardableResult func send(_ m: EventBridge.Message) -> Bool {
        guard let kind = m.known, let data = EventBridge.encode(m) else { return false }
        return write(data, kind.box, m.id)
    }
    /// Every message waiting in a box, oldest first. One that cannot be read is left where it is.
    func messages(_ box: EventBridge.Box) -> [EventBridge.Message] {
        keys(box).compactMap { EventBridge.decode(EventBridge.Message.self, from: read(box, $0)) }
            .sorted { ($0.sent, $0.id) < ($1.sent, $1.id) }
    }
    func done(_ m: EventBridge.Message, in box: EventBridge.Box) { delete(box, m.id) }
}

/// The real thing: generic-password items in the group both apps may read. Never synced to iCloud Keychain.
struct KeychainBridge: BridgeStore {
    private func query(_ box: EventBridge.Box, _ key: String?) -> [String: Any] {
        var q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: box.rawValue,
                                kSecAttrAccessGroup as String: EventBridge.group,
                                kSecUseDataProtectionKeychain as String: true]
        if let key { q[kSecAttrAccount as String] = key }
        return q
    }
    func read(_ box: EventBridge.Box, _ key: String) -> Data? {
        var q = query(box, key)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }
    @discardableResult func write(_ data: Data, _ box: EventBridge.Box, _ key: String) -> Bool {
        let q = query(box, key)
        let status = SecItemUpdate(q as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        var add = q
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        add[kSecAttrLabel as String] = "Finance Steward and PARAGON"
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }
    func keys(_ box: EventBridge.Box) -> [String] {
        var q = query(box, nil)
        q[kSecReturnAttributes as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitAll
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let rows = out as? [[String: Any]] else { return [] }
        return rows.compactMap { $0[kSecAttrAccount as String] as? String }
    }
    func delete(_ box: EventBridge.Box, _ key: String) {
        SecItemDelete(query(box, key) as CFDictionary)
    }
}

/// Tests, the sample and pictures: the same boxes, kept in memory only.
final class MemoryBridge: BridgeStore, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: Data] = [:]
    private func name(_ box: EventBridge.Box, _ key: String) -> String { box.rawValue + "|" + key }
    func read(_ box: EventBridge.Box, _ key: String) -> Data? { lock.withLock { items[name(box, key)] } }
    @discardableResult func write(_ data: Data, _ box: EventBridge.Box, _ key: String) -> Bool {
        lock.withLock { items[name(box, key)] = data }
        return true
    }
    func keys(_ box: EventBridge.Box) -> [String] {
        let prefix = box.rawValue + "|"
        return lock.withLock { items.keys.filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) } }
    }
    func delete(_ box: EventBridge.Box, _ key: String) { lock.withLock { _ = items.removeValue(forKey: name(box, key)) } }
}
