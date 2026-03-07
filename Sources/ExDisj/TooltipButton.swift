//
//  TooltipButton.swift
//  Edmund
//
//  Created by Hollan Sellars on 6/22/25.
//

import SwiftUI

/// Displays a button that shows a popover message.
public struct TooltipButton : View {
    /// Constructs the button with a specified message.
    public init(_ text: LocalizedStringKey) {
        self.text = text
    }
    
    private let text: LocalizedStringKey;
    @State private var showTooltip = false;
    
    public var body: some View {
        Button(action: {
            showTooltip = true
        }) {
            Image(systemName: "questionmark.circle")
        }.sheet(isPresented: $showTooltip) {
            VStack {
                Text(text)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    
                HStack {
                    Spacer()
                    
                    Button("Ok") {
                        showTooltip = false
                    }.buttonStyle(.borderedProminent)
                }
            }.padding()
        }
        .buttonStyle(.borderless)
    }
}

#Preview {
    VStack {
        Spacer()
        
        HStack {
            Spacer()
            TooltipButton("Here is some small text")
            
            TooltipButton("Large Text: \(String(repeating: "Hello! ", count: 100))")
            Spacer()
        }.padding()
        
        Spacer()
    }
}
