//
//  TopicPresenter.swift
//  ExDisj
//
//  Created by Hollan Sellars on 7/12/25.
//

import SwiftUI
import MarkdownUI

/// Presents the content of a ``LoadedHelpTopic``.
fileprivate struct TopicContentPresenter : View {
    let over: LoadedHelpTopic;
    
    var body: some View {
        ScrollView {
            Markdown(over.content)
        }
    }
}

/// Presents the page of a ``LoadedHelpTopic``.
internal struct TopicPagePresenter : View {
    let over: LoadedHelpTopic;
    
    var body: some View {
        VStack {
            HStack {
                Text(over.name)
                    .font(.title)
                Spacer()
            }
            
            HStack {
                Text("Topic")
                    .font(.subheadline)
                    .italic()
                
                Spacer()
            }
            
            TopicContentPresenter(over: over)
        }
    }
}

/// Presents a ``TopicFetchError``.
internal struct TopicErrorView : View {
    let e: TopicFetchError
    
    var body: some View {
        switch e {
            case .engineLoading:
                Text("The help system is not done loading. Please wait, and refresh.")
                Text("If this is a common or persistent issue, please report it.")
                
            case .fileReadError(let ie):
                Text("Edmund was not able to obtain the guide's contents.")
                Text("Error description: \(ie)")
                
            case .isAGroup:
                Text("Edmund expected a single topic, but got a group of topics instead.")
                Text("This is not an issue caused by you, but the developer.")
                Text("Please report this issue.")
            case .notFound:
                Text("Edmund could not find that topic.")
                Text("This is not an issue caused by you, but the developer.")
                Text("Please report this issue.")
        }
    }
}

/// Presents a help topic from a spevidic ``HelpResourceID``.
public struct TopicPresenter : View, HelpPresenterContentProtocol {
    /// Loads the presenter around a specific key.
    public init(_ key: HelpResourceID) {
        self.key = key
    }
    
    private let key: HelpResourceID;
    
    private func refresh(_ engine: HelpEngine, _ data: Binding<TopicLoadState>) async {
        await engine.getTopic(id: key, deposit: data)
    }
    
    public var body: some View {
        VStack {
            HStack {
                Text(key.name)
                    .font(.title)
                Spacer()
            }
            
            HStack {
                Text("Topic")
                    .font(.subheadline)
                    .italic()
                
                Spacer()
            }
            
            HelpResourcePresenter(refresh: refresh, error: TopicErrorView.init, content: TopicContentPresenter.init)
        }.padding()
    }
}

@available(macOS 14, iOS 17, *)
#Preview {
    let engine = HelpEngine()
    
    TopicPresenter(.init(rawValue: "Help/Introduction.md"))
        .environment(\.helpEngine, engine)
        .frame(width: 400, height: 300)
        .task {
            await engine.walkDirectory(locator: DefaultHelpResourcesLocator.self)
        }
}
