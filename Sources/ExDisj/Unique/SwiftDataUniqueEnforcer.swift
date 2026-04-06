//
//  SwiftDataUniqueEnforcer.swift
//  ExDisj
//
//  Created by Hollan Sellars on 4/6/26.
//

import Foundation
import SwiftData

/*
 private func fetchFor<T>(forType: T.Type, store: ModelContainer) async throws -> IdentifierBundle
 where T: UniqueElement & PersistentModel {
 let desc = FetchDescriptor<T>();
 logger?.debug("UniqueEngine: Processing type \(String(describing: T.self))");
 
 return try await Task(priority: .background) {
 let cx = ModelContext(store);
 
 let fetched: [T] = try cx.fetch(desc);
 var result = Set<AnyHashable>();
 for item in fetched {
 let id = AnyHashable(item.uID);
 
 guard !result.contains(id) else {
 logger?.debug("UniqueEngine: Type '\(String(describing: T.self))' has a non-unique identifier: \(String(describing: item.uID))");
 throw UniqueFailureError(value: id);
 }
 
 result.insert(id);
 }
 
 logger?.debug("UniqueEngine: Processed type \(String(describing: T.self))");
 return .init(id: T.objId, reserved: result);
 }.value;
 }
 
 
 public func fill<each C>(store: ModelContainer, forModels: repeat (each C).Type) async throws
 where repeat each C: UniqueElement & PersistentModel {
 logger?.info("UniqueEngine: Begining database walk.");
 var result: Dictionary<ObjectIdentifier, Set<AnyHashable>> = .init();
 
 for model in repeat (each forModels) {
 let partialResult = try await fetchFor(forType: model, store: store);
 
 result[partialResult.id] = partialResult.reserved;
 }
 
 logger?.info("UniqueEngine: Completed walk.");
 
 self.data = result;
 }
 
 */
