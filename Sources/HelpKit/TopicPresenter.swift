//
//  TopicPresenter.swift
//  ExDisj
//
//  Created by Hollan Sellars on 7/12/25.
//

import SwiftUI

/// Presents the content of a ``LoadedHelpTopic``.
fileprivate struct TopicContentPresenter : View {
    let over: LoadedHelpTopic;
    
    var body: some View {
        ScrollView {
            Text(over.content)
                .multilineTextAlignment(.leading)
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
    // TODO: Update topic error view to not be ass
    let e: TopicFetchError
    
    var body: some View {
        switch e {
            case .engineLoading:
                Text("The help system is not done loading. Please wait, and refresh.")
                Text("If this is a common or persistent issue, please report it.")
                
            case .fileReadError(let ie):
                Text("We were not able to obtain the guide's contents.")
                Text("Error description: \(ie.localizedDescription)")
                
            case .isAGroup:
                Text("We expected a single topic, but got a group of topics instead.")
                Text("This is not an issue caused by you, but the developer.")
                Text("Please report this issue.")
            case .notFound:
                Text("The specified topic could not be found.")
                Text("This is not an issue caused by you, but the developer.")
                Text("Please report this issue.")
                
            case .unsupportedFileType(_):
                Text("The topic pointed to an unsupported file type. Please reach out to the developer.")
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
    let lorem = AttributedString("""
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi pharetra quam vel dui feugiat venenatis nec sit amet justo. Duis et eros nunc. Curabitur varius ultrices scelerisque. Mauris condimentum quam ut ligula rutrum pellentesque. Duis malesuada finibus nibh. Mauris congue, velit viverra efficitur fringilla, orci lacus vulputate urna, at consectetur turpis nunc non diam. Nulla nunc dolor, ornare ultrices ultricies sit amet, semper sit amet sem. Pellentesque convallis aliquet nunc, sed rhoncus ligula porta non.
        
        Aenean mauris nisl, accumsan in consequat sed, fringilla non enim. Cras egestas tincidunt nisi, molestie maximus velit pellentesque sit amet. Aenean diam turpis, rhoncus nec neque at, gravida sodales nulla. Cras dictum metus eu semper maximus. Maecenas eget lobortis quam. Proin id vulputate augue. Fusce pretium urna vel dui varius, a vehicula dolor ornare. Suspendisse faucibus purus ut felis ornare vestibulum. Fusce tincidunt viverra nisi, mattis aliquet tortor suscipit nec. Duis vestibulum, lacus ut interdum varius, magna est varius erat, scelerisque faucibus libero tortor ultrices sem. Nulla sit amet orci quis metus commodo semper quis et est. Proin dignissim tristique purus vitae placerat.
        
        Pellentesque blandit semper aliquet. Donec interdum nisl sed orci ultricies, sit amet tempus est tincidunt. Etiam quam massa, convallis ac egestas a, eleifend in lorem. In nec sodales nibh, sed lacinia nulla. Praesent ullamcorper, mauris ut porta dapibus, odio tellus rutrum lorem, vitae posuere mauris urna id lectus. Morbi placerat tempus mollis. Nulla gravida, erat quis laoreet lobortis, orci lectus iaculis mauris, a vestibulum ante nisl vestibulum tortor. Sed suscipit rutrum lobortis. Sed purus tortor, finibus quis ullamcorper ac, rhoncus vel elit.
        
        Suspendisse odio risus, varius a mauris vel, condimentum finibus ex. Fusce vel semper lorem. Integer ac erat id diam ultrices lobortis in ut urna. Maecenas a quam leo. Donec lobortis convallis gravida. Cras vehicula, mi id volutpat congue, ligula nunc mollis mauris, vitae faucibus ipsum diam sed lectus. Ut mauris enim, lacinia et commodo sit amet, gravida ut libero.
        
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi venenatis orci dui, vel iaculis mauris mattis at. Morbi imperdiet pretium nibh, ut tincidunt neque bibendum non. Fusce ullamcorper faucibus dui pretium commodo. Aenean mattis lorem massa, eget malesuada nibh ultrices sit amet. Fusce placerat dignissim ipsum quis volutpat. Nulla leo felis, sollicitudin a malesuada in, blandit non felis. Mauris accumsan leo eget turpis placerat fringilla. Pellentesque vitae mollis tortor, eu congue metus. Donec faucibus efficitur nibh, ut aliquam metus consectetur sit amet. Aenean blandit venenatis nisi. Curabitur tincidunt tempor tincidunt.
    """);
    
    TopicContentPresenter(
        over: .init(
            id: .init(),
            content: lorem
        )
    ).frame(width: 400, height: 300)
        .padding()
}
