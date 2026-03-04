//
//  TopicButton.swift
//  Edmund
//
//  Created by Hollan Sellars on 7/12/25.
//

import SwiftUI

/// Choices for styling ``TopicButton``.
public enum TopicButtonStyle {
    /// Displays only the icon, a question mark with a circle.
    case compact
    /// Displays only the text, "Help"
    case textOnly
    /// Displays the icon, a question mark with a circle, and the text, "Help".
    case label
}

/// A `View` that can present information about a specific help resource.
public protocol HelpPresenterContentProtocol : View {
    /// Constructs the view, passing in the ``HelpResourceID`` to associate with.
    init(_ key: HelpResourceID);
}

/// A button that will load a specific help resource and present the content in a sheet.
public struct HelpButtonBase<P> : View where P: HelpPresenterContentProtocol {
    /// Constructs the button around a loaded ``HelpResourceID``
    /// - Parameters:
    ///     - key: The ``HelpResourceID`` to load from the ``HelpEngine``
    public init(_ key: HelpResourceID) {
        self.key = key
    }
    /// Constructs the button around a relative path, `key`.
    /// - Parameters:
    ///     - key: The relative path of the help resource to present.
    public init(_ key: String) {
        self.init(HelpResourceID(rawValue: key))
    }
    /// Constructs the button around a relative path, `key`.
    /// - Parameters:
    ///     - key: The relative path of the help resource to present.
    public init(_ key: [String]) {
        self.init(HelpResourceID(parts: key))
    }
    
    private let key: HelpResourceID;
    @State private var showSheet: Bool = false;
    private var style: TopicButtonStyle = .label
    
    /// Modifies the style of the view.
    public func topicButtonStyle(_ new: TopicButtonStyle) -> HelpButtonBase<P> {
        var result = self
        result.style = new
        return result
    }
    
    public var body: some View {
        Button {
            showSheet = true
        } label: {
            switch style {
                case .compact: Image(systemName: "questionmark.circle")
                case .textOnly: Text("Help")
                case .label: Label("Help", systemImage: "questionmark.circle")
            }
        }.sheet(isPresented: $showSheet) {
            P(self.key)
        }
    }
}

/// A shortcut to present a topic in a sheet.
public typealias TopicButton = HelpButtonBase<TopicPresenter>;

/// A shortcut to present a topic group in a sheet.
@available(macOS 13, iOS 16, *)
public typealias TopicGroupButton = HelpButtonBase<TopicGroupPresenter>;

/// A toolbar button that will load a specific help resource and present the content in a sheet.
public struct HelpToolbarButton<P> : CustomizableToolbarContent where P: HelpPresenterContentProtocol {
    /// Constructs the button around a loaded ``HelpResourceID``
    /// - Parameters:
    ///     - key: The ``HelpResourceID`` to load from the ``HelpEngine``
    ///     - placement: Where to locate the toolbar item.
    public init(_ key: HelpResourceID, placement: ToolbarItemPlacement = .automatic) {
        self.key = key
        self.placement = placement
    }
    /// Constructs the button around a relative path, `key`.
    /// - Parameters:
    ///     - key: The relative path of the help resource to present.
    ///     - placement: Where to locate the toolbar item.
    public init(_ key: String, placement: ToolbarItemPlacement = .automatic) {
        self.init(HelpResourceID(rawValue: key), placement: placement)
    }
    /// Constructs the button around a relative path, `key`.
    /// - Parameters:
    ///     - key: The relative path of the help resource to present.
    ///     - placement: Where to locate the toolbar item.
    public init(_ key: [String], placement: ToolbarItemPlacement = .automatic) {
        self.init(HelpResourceID(parts: key), placement: placement)
    }
    
    private let key: HelpResourceID;
    private let placement: ToolbarItemPlacement;
    
    @ToolbarContentBuilder
    public var body: some CustomizableToolbarContent {
        ToolbarItem(id: "helpTopic", placement: placement) {
            HelpButtonBase<P>(key)
                .topicButtonStyle(.label)
        }
    }
}

/// A shortcut to present a topic in a sheet.
public typealias TopicToolbarButton = HelpToolbarButton<TopicPresenter>;

/// A shortcut to present a topic group in a sheet.
@available(macOS 13, iOS 16, *)
public typealias TopicGroupToolbarButton = HelpToolbarButton<TopicGroupPresenter>;

@available(macOS 14, iOS 17, *)
#Preview {
    TopicButton("Help/Welcome.md")
        .padding()
}
