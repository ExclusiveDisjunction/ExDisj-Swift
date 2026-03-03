//
//  HelpResourcePresenter.swift
//  Edmund
//
//  Created by Hollan Sellars on 7/13/25.
//

import SwiftUI

/// Presents a specific help resource by combining its error and content views.
public struct HelpResourcePresenter<T, E, ErrorContent, Content> : View
where ErrorContent: View,
      Content: View,
      T: Identifiable,
      T.ID == HelpResourceID,
      E: Error {
    
    public init(refresh: @escaping (HelpEngine, Binding<ResourceLoadState<T, E>>) async -> Void, @ViewBuilder error: @escaping (E) -> ErrorContent, @ViewBuilder content: @escaping (T) -> Content) {
        self.refresh = refresh;
        self.error = error;
        self.content = content;
        self.data = data;
    }
    
    @Environment(\.helpEngine) private var helpEngine;
    @Environment(\.dismiss) private var dismiss;
    
    private let refresh: (HelpEngine, Binding<ResourceLoadState<T, E>>) async -> Void;
    private let error: (E) -> ErrorContent;
    private let content: (T) -> Content;
    
    @State private var data: ResourceLoadState<T, E> = .loading;
    @State private var task: Task<Void, Never>? = nil;
    
    private func performRefresh() {
        if let oldTask = task {
            oldTask.cancel()
        }
        
        let engine = helpEngine;
        
        task = Task { [$data] in
            await refresh(engine, $data)
        }
    }
    
    @ViewBuilder
    private var statusView: some View {
        Spacer()
        
        ProgressView() {
            Text("Loading")
        }
        
        Button(action: performRefresh) {
            Image(systemName: "arrow.trianglehead.clockwise.rotate.90")
        }
        
        Spacer()
    }
    
    
    public var body: some View {
        switch data {
            case .loading:
                statusView
                    .onAppear {
                        performRefresh()
                    }
            case .error(let e):
                Spacer()
                
                error(e)
                Button("Refresh", action: performRefresh)
                
                Spacer()
            case .loaded(let v):
                VStack {
                    content(v)
                    HStack {
                        Spacer()
                        Button("Ok") {
                            dismiss()
                        }.buttonStyle(.borderedProminent)
                    }
                }
        }
    }
}
