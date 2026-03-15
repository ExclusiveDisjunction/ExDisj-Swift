//
//  FormBody.swift
//  ExDisj
//
//  Created by Hollan Sellars on 3/3/26.
//

import SwiftUI

/// A button that is labeled "Ok" and dismisses the current view.
public struct OkButton : View {
    public init() {
        
    }
    
    @Environment(\.dismiss) private var dismiss;
    
    public var body : some View {
        Button("Ok") {
            dismiss()
        }.buttonStyle(.borderedProminent)
    }
}

/// A simplified template for formatting and arranging sheet content.
///
/// This view takes in two view builders: Content and Actions. The content appears after the title, and is the main visual focus of the sheet. The Actions appear at the bottom right of the sheet, and typically close the sheet.
/// The Actions are configurable, but if omitted, it defaults to ``OkButton``, which will just dismiss the sheet.
public struct SheetBody<Content, Actions> {
    private let title: LocalizedStringKey;
    private let contentBuild: () -> Content;
    private let actionsBuild: () -> Actions;
    
    @Environment(\.dismiss) private var dismiss;
}
extension SheetBody : View where Content : View, Actions: View {
    /// Constructs the sheet with a title, content, and customizable actions.
    public init(_ title: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content, @ViewBuilder actions: @escaping () -> Actions) {
        self.title = title;
        self.contentBuild = content;
        self.actionsBuild = actions;
    }
    
    public var body: some View {
        VStack {
            HStack {
                Text(title)
                    .font(.title2)
                
                Spacer()
            }
            
            contentBuild()
            
            Spacer()
            
            HStack {
                Spacer()
                
                actionsBuild()
            }
        }.padding()
    }
}
extension SheetBody where Actions == OkButton, Content : View {
    /// Constructs the sheet with a title and content.
    ///
    /// Since the Actions are not specified, ``OkButton`` will be used, which dismisses the sheet.
    @MainActor
    public init(_ title: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) {
        self.init(
            title,
            content: content,
            actions: OkButton.init
        )
    }
}
