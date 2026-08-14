import Foundation

// Swiftgram — Regex Filters (AyuGram: ayu/features/filters/, entities.h RegexFilter)

public struct SGRegexFilter: Codable, Equatable {
    public var id: String
    public var text: String
    public var enabled: Bool
    public var reversed: Bool
    public var caseInsensitive: Bool
    public var dialogId: Int64?

    public init(
        id: String = UUID().uuidString,
        text: String,
        enabled: Bool = true,
        reversed: Bool = false,
        caseInsensitive: Bool = true,
        dialogId: Int64? = nil
    ) {
        self.id = id
        self.text = text
        self.enabled = enabled
        self.reversed = reversed
        self.caseInsensitive = caseInsensitive
        self.dialogId = dialogId
    }

    public static func fromJson(_ json: [String: Any]) -> SGRegexFilter? {
        guard let id = json["id"] as? String, !id.isEmpty,
              let text = json["text"] as? String, !text.isEmpty else {
            return nil
        }
        var filter = SGRegexFilter(id: id, text: text)
        filter.enabled = (json["enabled"] as? Bool) ?? true
        filter.reversed = (json["reversed"] as? Bool) ?? false
        filter.caseInsensitive = (json["caseInsensitive"] as? Bool) ?? true
        if let dialogId = json["dialogId"] as? Int64, dialogId != 0 {
            filter.dialogId = dialogId
        }
        return filter
    }

    public func toJson() -> [String: Any] {
        var json: [String: Any] = [
            "id": self.id,
            "text": self.text,
            "enabled": self.enabled,
            "reversed": self.reversed,
            "caseInsensitive": self.caseInsensitive
        ]
        if let dialogId = self.dialogId {
            json["dialogId"] = dialogId
        }
        return json
    }
}

public final class SGFilterEngine {
    public static let shared = SGFilterEngine()

    private var regexCache: [String: NSRegularExpression?] = [:]

    private init() {}

    private func regex(for filter: SGRegexFilter) -> NSRegularExpression? {
        if let cached = self.regexCache[filter.id] {
            return cached
        }
        var options: NSRegularExpression.Options = []
        if filter.caseInsensitive {
            options.insert(.caseInsensitive)
        }
        let expression = try? NSRegularExpression(pattern: filter.text, options: options)
        self.regexCache[filter.id] = expression
        return expression
    }

    // Semantics mirrors AyuGram FiltersController::isFiltered:
    // OR across all enabled filters, reversed flips the match result.
    // Invalid regex never matches (like ICU failure in AyuGram).
    public func isFiltered(text: String, dialogId: Int64) -> Bool {
        guard !text.isEmpty else {
            return false
        }
        for filter in SGSimpleSettings.shared.regexFilters {
            guard filter.enabled else {
                continue
            }
            if let filterDialogId = filter.dialogId, filterDialogId != dialogId {
                continue
            }
            guard let expression = self.regex(for: filter) else {
                continue
            }
            let match = expression.firstMatch(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length)) != nil
            if (!filter.reversed && match) || (filter.reversed && !match) {
                return true
            }
        }
        return false
    }

    public func invalidate() {
        self.regexCache.removeAll()
    }
}
