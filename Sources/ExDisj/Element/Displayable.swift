//
//  Displayable.swift
//  ExDisj
//
//  Created by Hollan Sellars on 7/2/25.
//

import SwiftUI

/// Represents a type that can be displayed on the user interface with a `LocalizedStringKey`.
public protocol Displayable {
    /// The UI presentable content to show corresponding to the current value.
    var display: LocalizedStringKey { get }
}

/// A type wrapping the display information for a specific data type.
public struct TypeTitleStrings {
    public init(singular: LocalizedStringKey, plural: LocalizedStringKey, inspect: LocalizedStringKey, edit: LocalizedStringKey, add: LocalizedStringKey) {
        self.singular = singular
        self.plural = plural
        self.inspect = inspect
        self.edit = edit
        self.add = add
    }
    
    /// A singluar value (Ex. Book)
    public let singular : LocalizedStringKey;
    /// A plural value (Ex. Books)
    public let plural   : LocalizedStringKey;
    /// The title used for inspecting (Ex. Inspect Book)
    public let inspect  : LocalizedStringKey;
    /// The title used for editing (Ex. Edit Book)
    public let edit     : LocalizedStringKey;
    /// The title used for adding (Ex. Add Book)
    public let add      : LocalizedStringKey;
}
/// Represents a type that can have itself be displayed as a title.
public protocol TypeTitled {
    /// The display values that can be used to render the type.
    static var typeDisplay : TypeTitleStrings { get }
}
