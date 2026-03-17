//
//  Animation.swift
//  ExDisj
//
//  Created by Hollan Sellars on 3/14/26.
//

import SwiftUI

/// Based on a boolean predicate, use animation. This will call swift UI's `withAnimation` if `on` is true.
/// - Parameters:
///     - isOn: Determines if an animation should be shown by the action in `body`.
///     - animation: The animation to display
///     - body: The action to watch animation states.
public func optionalWithAnimation<Result>(isOn: Bool, _ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result {
    guard isOn else {
        return try withAnimation(animation, body)
    }
    
    return try body();
}

/// Based on a boolean predicate, use animation. This will call swift UI's `withAnimation` if `on` is true.
/// - Parameters:
///     - isOn: Determines if an animation should be shown by the action in `body`.
///     - completionCriteria: An animation completion criteria to determine when the animation is finished.
///     - animation: The animation to display
///     - body: The action to watch animation states.
///     - completion: An action to run after the animation completes.
@available(macOS 14, iOS 17, *)
public func optionalWithAnimation<Result>(isOn: Bool, completionCriteria: AnimationCompletionCriteria, _ animation: Animation? = .default, _ body: () throws -> Result, completion: @escaping () -> Void) rethrows -> Result {
    guard isOn else {
        return try withAnimation(animation, completionCriteria: completionCriteria, body, completion: completion)
    }
    
    return try body();
}
