//
//  UniqueId.swift
//  ExDisj
//
//  Created by Hollan Sellars on 4/6/26.
//

import Foundation

public protocol UniqueId : Hashable, Sendable, CustomStringConvertible { }
extension String : UniqueId { }
extension Int : UniqueId { }
extension Int8 : UniqueId { }
extension Int16 : UniqueId { }
extension Int32 : UniqueId { }
extension Int64 : UniqueId { }
extension UInt : UniqueId { }
extension UInt8 : UniqueId { }
extension UInt16 : UniqueId { }
extension UInt32 : UniqueId { }
extension UInt64 : UniqueId { }
extension UUID : UniqueId { }
