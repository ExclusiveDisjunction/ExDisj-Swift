//
//  String.swift
//  ExDisj
//
//  Created by Hollan Sellars on 3/24/26.
//

import Foundation

extension String {
    public static let allCharacters = String("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789");
    
    public static func randomString(ofLength: Int) -> String {
        var generator = SystemRandomNumberGenerator();
        return String(
            (1...ofLength).map { _ in String.allCharacters.randomElement(using: &generator)! }
        )
    }
}

