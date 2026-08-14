import Foundation
import Postbox

// MARK: Swiftgram — anti-delete: маркер удалённого сообщения (AyuGram: HistoryItem::setDeleted)
// Сообщение не удаляется из Postbox, а помечается этим атрибутом; рендер показывает deletedMark.
public class DeletedMessageAttribute: MessageAttribute {
    public let date: Int32
    
    public init(date: Int32) {
        self.date = date
    }
    
    required public init(decoder: PostboxDecoder) {
        self.date = decoder.decodeInt32ForKey("d", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.date, forKey: "d")
    }
}

// MARK: Swiftgram — anti-delete: ревизия сообщения (AyuGram: EditedMessage / addEditedMessage)
public final class EditHistoryRevision: PostboxCoding, Equatable {
    public let text: String
    public let entities: [MessageTextEntity]
    public let date: Int32
    
    public init(text: String, entities: [MessageTextEntity], date: Int32) {
        self.text = text
        self.entities = entities
        self.date = date
    }
    
    public init(decoder: PostboxDecoder) {
        self.text = decoder.decodeStringForKey("t", orElse: "")
        self.entities = decoder.decodeObjectArrayWithDecoderForKey("e")
        self.date = decoder.decodeInt32ForKey("d", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.text, forKey: "t")
        encoder.encodeObjectArray(self.entities, forKey: "e")
        encoder.encodeInt32(self.date, forKey: "d")
    }
    
    public static func ==(lhs: EditHistoryRevision, rhs: EditHistoryRevision) -> Bool {
        return lhs.text == rhs.text && lhs.entities == rhs.entities && lhs.date == rhs.date
    }
}

// MARK: Swiftgram — anti-delete: история правок (AyuGram: saveMessagesHistory / hasRevisions)
public class EditedHistoryMessageAttribute: MessageAttribute {
    public let revisions: [EditHistoryRevision]
    
    public init(revisions: [EditHistoryRevision]) {
        self.revisions = revisions
    }
    
    required public init(decoder: PostboxDecoder) {
        self.revisions = decoder.decodeObjectArrayWithDecoderForKey("r")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.revisions, forKey: "r")
    }
}