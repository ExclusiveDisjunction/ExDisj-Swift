//
//  TopicGroupPresenter.swift
//  Edmund
//
//  Created by Hollan Sellars on 7/12/25.
//

import SwiftUI

/// Presents the children of a ``LoadedHelpGroup`` as selectable items.
fileprivate struct HelpGroupPagePresenter : View {
    let over: LoadedHelpGroup;
    @Binding var selectedID: HelpResourceID?;
    
    @ViewBuilder
    private func content(_ name: String) -> some View {
        HStack {
            Image(systemName: "arrow.right")
            Text(name)
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                Text(over.name)
                    .font(.title)
                Spacer()
            }
            
            HStack {
                Text("Group")
                    .font(.subheadline)
                    .italic()
                
                Spacer()
            }
            
            List(selection: $selectedID) {
                Section(header: Text("Topics")) {
                    ForEach(over.topicChildren) { topic in
                        content(topic.name)
                    }
                }
                
                Section(header: Text("Groups")) {
                    ForEach(over.groupChildren) { group in
                        content(group.name)
                    }
                }
            }
            
            Spacer()
        }
    }
}

/// Presents a ``LoadedHelpGroup`` as a `NavigationSplitView`.
@available(macOS 13, iOS 16, *)
fileprivate struct LoadedHelpGroupPresenter : View {
    init(data: LoadedHelpGroup) {
        self.data = data
        self.navigationTitle = data.name.isEmpty ? "Edmund Help" : data.name
    }
    init(data: LoadedHelpGroup, title: String) {
        self.data = data
        self.navigationTitle = title
    }
    let data: LoadedHelpGroup;
    let navigationTitle: String;
    
    @State private var selectedID: HelpResourceID? = nil;
    @State private var selected: LoadedHelpResource? = nil;
    
    private var content: some View {
        NavigationSplitView {
            VStack {
                Text("Help")
                    .font(.title2)
                
                List(data.children, children: \.children, selection: $selectedID) { element in
                    Text(element.name)
                }
            }
        } detail: {
            VStack {
                if let selected = selected {
                    switch selected {
                        case .topic(let topic):
                            TopicPagePresenter(over: topic)
                        case .group(let group):
                            HelpGroupPagePresenter(over: group, selectedID: $selectedID)
                    }
                }
                else if selectedID != nil {
                    Text("Sorry, but it looks like that topic or group could not be loaded.")
                }
            }.padding()
        }.navigationTitle(navigationTitle)
    }
    
    private func selectedIDChanged(selectedID: HelpResourceID?) {
        withAnimation {
            self.selected = if let selectedID = selectedID {
                data.findChild(id: selectedID)
            }
            else {
                nil
            }
        }
    }
    
    var body: some View {
        if #available(macOS 14, iOS 17, *) {
            content
                .onChange(of: selectedID) { _, selectedID in
                    selectedIDChanged(selectedID: selectedID)
                }
        }
        else {
            content.onChange(of: selectedID, perform: selectedIDChanged)
        }
            
    }
}

/// Presents a ``GroupFetchError``.
fileprivate struct GroupFetchErrorPresenter : View {
    let e: GroupFetchError;
    
    var body: some View {
        VStack {
            switch e {
                case .engineLoading:
                    Text("The help system is not done loading. Please wait, and refresh.")
                    Text("If this is a common or persistent issue, please report it.")
                    
                case .isATopic:
                    Text("Edmund expected a group of topics, but got a single topic instead.")
                    Text("This is not an issue caused by you, but the developer.")
                    Text("Please report this issue.")
                case .notFound:
                    Text("Edmund could not find that topic.")
                    Text("This is not an issue caused by you, but the developer.")
                    Text("Please report this issue.")
                    
                case .topicLoad(let t):
                    Text("A sub-topic could not be loaded. Here are the errors:")
                    TopicErrorView(e: t)
            }
        }
    }
}

/// Presents a topic group from a ID, or presents the root.
@available(macOS 13, iOS 16, *)
public struct TopicGroupPresenter : View, HelpPresenterContentProtocol {
    /// Presents the help root.
    public init() {
        self.key = .init()
    }
    /// Presents a specific ``HelpResourceID``.
    public init(_ key: HelpResourceID) {
        self.key = key
    }
    
    private let key: HelpResourceID;
    
    private func refresh(_ engine: HelpEngine, _ data: Binding<GroupLoadState>) async {
        await engine.getGroup(id: key, deposit: data)
    }
    
    public var body: some View {
        HelpResourcePresenter(refresh: refresh, error: GroupFetchErrorPresenter.init, content: LoadedHelpGroupPresenter.init)
    }
}

/// Presents the root of the help tree.
@available(macOS 13, iOS 16, *)
public struct HelpTreePresenter : View {
    private func refresh(_ engine: HelpEngine, _ data: Binding<GroupLoadState>) async {
        await engine.getTree(deposit: data)
    }
    
    public var body: some View {
        HelpResourcePresenter(refresh: refresh, error: GroupFetchErrorPresenter.init, content: LoadedHelpGroupPresenter.init)
    }
}

@available(macOS 14, iOS 17, *)
#Preview {
    let engine = HelpEngine()
    
    TopicGroupPresenter(.init(rawValue: "Help"))
        .environment(\.helpEngine, engine)
        .task {
            await engine.walkDirectory(locator: DefaultHelpResourcesLocator.self)
        }
}
