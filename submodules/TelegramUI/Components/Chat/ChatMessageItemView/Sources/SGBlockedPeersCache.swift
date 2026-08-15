import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import AccountContext

// Swiftgram — кэш заблокированных пиров для hideFromBlocked
// (AyuGram: FiltersController::isBlocked, filters_controller.cpp)

public final class SGFiltersBlockedPeers {
    public static let shared = SGFiltersBlockedPeers()

    private var contexts: [Int64: AccountContext] = [:]
    private var disposes: [Int64: Disposable] = [:]
    private var blockedBareIds: [Int64: Set<Int64>] = [:]
    private var initializedAccountIds: Set<Int64> = []

    private init() {}

    public func isBlocked(_ peerId: EnginePeer.Id, context: AccountContext) -> Bool {
        let accountId = context.account.peerId.id._internalGetInt64Value()
        if !self.initializedAccountIds.contains(accountId) {
            self.initializedAccountIds.insert(accountId)
            self.contexts[accountId] = context
            let blockedContext = BlockedPeersContext(account: context.account, subject: .blocked)
            let disposable = blockedContext.state.start(next: { [weak self] state in
                var ids = Set<Int64>()
                for peer in state.peers {
                    ids.insert(peer.peerId.id._internalGetInt64Value())
                }
                self?.blockedBareIds[accountId] = ids
            })
            self.disposes[accountId] = disposable
        }
        return self.blockedBareIds[accountId]?.contains(peerId.id._internalGetInt64Value()) ?? false
    }
}