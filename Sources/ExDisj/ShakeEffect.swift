//
//  ShakeModifier.swift
//  Edmund
//
//  Created by Hollan Sellars on 6/25/25.
//

import SwiftUI

/// A geometry effect that will shake a view back and forth.
public struct ShakeEffect : GeometryEffect {
    public init(travelDistance: CGFloat = 8, shakesPerUnit: Int = 3) {
        self.travelDistance = travelDistance;
        self.shakesPerUnit = shakesPerUnit;
        self.animatableData = CGFloat()
    }
    
    private let travelDistance: CGFloat;
    private let shakesPerUnit: Int;
    public var animatableData: CGFloat;
    
    public func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = travelDistance * sin(animatableData * .pi * CGFloat(shakesPerUnit))
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
