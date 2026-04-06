//
//  NotificationToken.swift
//  ExDisj
//
//  Created by Hollan Sellars on 4/5/26.
//

import Foundation
import os

public actor NotificationToken {
    private struct InnerToken : @unchecked Sendable {
        let token: NSObjectProtocol;
    }
    
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        MainActor.sharedUnownedExecutor
    }
    
    @MainActor
    public init(_ inner: NSObjectProtocol, center: NotificationCenter) {
        let token = InnerToken(token: inner);
        self.tokenBox = .init(initialState: token);
        self.center = center;
    }
    deinit {
        self.cancel()
    }
    
    public static nonisolated func createAsync(center: NotificationCenter = .default, forName: NSNotification.Name?, object: (any Sendable)?, perform: @Sendable @escaping (Notification) -> Void) async -> NotificationToken? {
        return await MainActor.run {
            return create(center: center, forName: forName, object: object, perform: perform)
        }
    }
    @MainActor
    public static func create(center: NotificationCenter = .default, forName: NSNotification.Name?, object: Any?, perform: @Sendable @escaping (Notification) -> Void) -> NotificationToken {
        let token = center.addObserver(forName: forName, object: object, queue: OperationQueue.main, using: perform);
        
        return NotificationToken(token, center: center)
    }
    
    private let center: NotificationCenter;
    private let tokenBox: OSAllocatedUnfairLock<InnerToken?>;
    
    public nonisolated func cancel() {
        let token = tokenBox.withLock {
            let old = $0;
            $0 = nil;
            return old;
        };
        
        if let token {
            center.removeObserver(token.token);
        }
    }
}
