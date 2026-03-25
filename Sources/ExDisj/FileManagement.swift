//
//  FileManagement.swift
//  ExDisj
//
//  Created by Hollan Sellars on 3/24/26.
//

import Foundation
import UniformTypeIdentifiers
import CoreTransferable

public protocol UrlRepresentable : Sendable, ~Copyable {
    var path: URL { get }
}
extension URL : UrlRepresentable {
    public var path: URL { self }
}

@available(macOS 13, iOS 16, *)
public struct TemporaryFolderLease : ~Copyable, Sendable, UrlRepresentable {
    public init() throws {
        let name = String.randomString(ofLength: 15);
        
        path = FileManager.default.temporaryDirectory.appending(path: name);
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false);
    }
    deinit {
        try? FileManager.default.removeItem(at: path);
    }
    
    public let path: URL;
    
    public func appending(path: some StringProtocol) -> URL {
        return self.path.appending(path: path);
    }
    public func contentsOf(
        includingPropertiesForKeys: [URLResourceKey]?,
        options: FileManager.DirectoryEnumerationOptions = []
    ) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: includingPropertiesForKeys, options: options)
    }
    public func enumerator(
        includingPropertiesForKeys: [URLResourceKey]?,
        options: FileManager.DirectoryEnumerationOptions = [],
        errorHandler: ((URL, any Error) -> Bool)? = nil
    ) -> FileManager.DirectoryEnumerator? {
        FileManager.default.enumerator(
            at: self.path,
            includingPropertiesForKeys: includingPropertiesForKeys,
            options: options,
            errorHandler: errorHandler
        )
    }
    
    public func copyInto(sourceUrl: URL) throws {
        let newDestUrl = path.appending(path: sourceUrl.lastPathComponent);
        try FileManager.default.copyItem(at: sourceUrl, to: newDestUrl);
    }
    public func createSymbolicLink(withName: String, sourceUrl: URL) throws {
        let destinationName = path.appending(path: withName);
        try FileManager.default.createSymbolicLink(at: destinationName, withDestinationURL: sourceUrl);
    }
}

public struct AutoreleaseUrl: ~Copyable, Sendable, UrlRepresentable {
    public init(path: URL) {
        self._path = path;
    }
    deinit {
        if let path = self._path {
            try? FileManager.default.removeItem(at: path)
        }
    }
    
    private var _path: URL?;
    public var path: URL {
        get { _path! }
    }
    
    public consuming func take() -> URL {
        self._path = nil;
        return self._path!;
    }
    @available(macOS 13, iOS 16, *)
    public func appending(path: String) -> URL {
        self.path.appending(path: path)
    }
}

public final class DmgTransferable<R> : Sendable, Identifiable
where R: Sendable & ~Copyable {
    public init(path: consuming R, id: UUID = UUID()) {
        self.inner = path;
        self.id = id;
    }
    
    public let inner: R;
    public let id: UUID;
}
extension DmgTransferable : UrlRepresentable
where R: UrlRepresentable & ~Copyable {
    public var path: URL {
        self.inner.path
    }
    
   
}
@available(macOS 13, iOS 16, *)
extension DmgTransferable : Transferable
where R: UrlRepresentable & ~Copyable {
    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .diskImage) { repr in
            SentTransferredFile(repr.inner.path)
        }
    }
}
