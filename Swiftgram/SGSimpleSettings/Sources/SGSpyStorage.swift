import Foundation

// MARK: Swiftgram — spy: локальное хранилище событий прочтения (AyuGram: SpyMessageRead / SpyMessageContentsRead, entities.h:119-137).
// Данные не покидают устройство. Записи ограничены (cap на диалог и на всё хранилище).

public final class SGSpyStorage {
    public enum Kind: String {
        case read
        case contentsRead
    }
    
    public static let shared = SGSpyStorage()
    
    private static let readKey = "swiftgram_spy_read"
    private static let contentsReadKey = "swiftgram_spy_contents_read"
    private static let maxPerPeer = 200
    private static let maxTotal = 2000
    
    private let defaults: UserDefaults
    
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    // [peerIdString: [messageIdString: date]]
    private func load(_ kind: Kind) -> [String: [String: Int32]] {
        let key = kind == .read ? SGSpyStorage.readKey : SGSpyStorage.contentsReadKey
        guard let data = self.defaults.data(forKey: key),
              let dict = try? JSONDecoder().decode([String: [String: Int32]].self, from: data) else {
            return [:]
        }
        return dict
    }
    
    private func save(_ kind: Kind, _ dict: [String: [String: Int32]]) {
        let key = kind == .read ? SGSpyStorage.readKey : SGSpyStorage.contentsReadKey
        if let data = try? JSONEncoder().encode(dict) {
            self.defaults.set(data, forKey: key)
        }
    }
    
    public func record(kind: Kind, peerId: Int64, messageId: Int32, date: Int32) {
        var dict = self.load(kind)
        let peerKey = "\(peerId)"
        var messages = dict[peerKey] ?? [:]
        messages["\(messageId)"] = date
        while messages.count > SGSpyStorage.maxPerPeer {
            if let oldest = messages.min(by: { $0.value < $1.value }) {
                messages.removeValue(forKey: oldest.key)
            }
        }
        dict[peerKey] = messages
        var totalRecords = dict.reduce(0, { $0 + $1.value.count })
        while totalRecords > SGSpyStorage.maxTotal {
            if let oldestPeer = dict.min(by: {
                ($0.value.values.min() ?? 0) < ($1.value.values.min() ?? 0)
            }) {
                totalRecords -= oldestPeer.value.count
                dict.removeValue(forKey: oldestPeer.key)
            } else {
                break
            }
        }
        self.save(kind, dict)
    }
    
    public func date(kind: Kind, peerId: Int64, messageId: Int32) -> Int32? {
        let dict = self.load(kind)
        return dict["\(peerId)"]?["\(messageId)"]
    }
    
    public func clear() {
        self.defaults.removeObject(forKey: SGSpyStorage.readKey)
        self.defaults.removeObject(forKey: SGSpyStorage.contentsReadKey)
    }
}
