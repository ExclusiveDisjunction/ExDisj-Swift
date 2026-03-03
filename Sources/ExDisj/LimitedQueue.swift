//
//  LimitedQueue.swift
//  ExDisj
//
//  Created by Hollan Sellars on 7/12/25.
//

/// Represents a queue that has a fixed capacity. As elements keep getting added, the oldest element gets removed, and the new one is added.
/// This only makes one heap allocation, and will never resize its data.
public struct LimitedQueue<T> {
    /// The data stored internally
    fileprivate var data: [T]
    /// The current position inside of data
    fileprivate private(set) var p: Int;
    /// The total number of allocated elements
    public private(set) var count: Int;
    
    /// Constructs a limited queue over some capacity and a default `T` value.
    /// The capacity will allocate an internal array, of which will never be resized.
    /// The array will be filled with `with` values, so that the array can be built.
    /// Note that the value of `with` will never be returned from this array (unless directly stored)
    /// - Parameters:
    ///     - capacity: The total number of possible elements to be stored in the structure
    ///     - with: A default value to used to build the array. This value will never be returned (unless directly stored)
    public init(capacity: Int, with: T) {
        assert(capacity > 0, "The capacity of a LimitedQueue cannot be zero or less")
        
        self.data = .init(repeating: with, count: capacity)
        self.count = 0;
        self.p = 0;
    }
    
    /// The total number of possible elements to be stored in the structure
    public var capacity: Int {
        data.count
    }
    /// When true, the queue has reached its limit.
    /// This implies that calling `.append` will return a value, and that the oldest element will be removed from the queue.
    public var isFull: Bool {
        self.count >= data.count
    }
    
    /// The current front index (already mapped directly from data's indexes)
    fileprivate var frontIndex: Int? {
        guard !self.isEmpty else {
            return nil
        }
        
        if self.p == 0 || !self.isFull {
            return 0
        }
        else {
            return self.p
        }
    }
    /// The current back index (already mapped directly from data's indexes)
    fileprivate var backIndex: Int? {
        guard !self.isEmpty else {
            return nil
        }
        
        if self.p != 0 {
            return self.p - 1
        }
        else {
            return self.capacity - 1
        }
    }
    
    /// The value currently at the front of the queue.
    public var front: T? {
        guard let index = frontIndex else {
            return nil
        }
        
        return self.data[index]
    }
    /// The value currently at the back of the queue.
    public var back: T? {
        guard let index = backIndex else {
            return nil
        }
        
        return self.data[index]
    }
    
    /// Resets all stored data
    /// Note that this does not clear out `capacity` or the internal buffer.
    /// It simply just resets the `count` to zero.
    public mutating func clear() {
        self.p = 0;
        self.count = 0;
    }
    
    /// Appends a new element to the queue, returning the oldest element if `self.isFull` is true.
    /// This function will always return `nil` if `self.isFull` is `false`, but non-`nil` otherwise.
    /// For example:
    ///
    ///     var queue = LimitedQueue<Int>(capacity: 3, with: 0);
    ///
    ///     #expect(queue.append(1) == nil)
    ///     #expect(queue.append(2) == nil)
    ///     #expect(queue.append(3) == nil);
    ///     #expect(queue.front == 1);
    ///     #expect(queue.back  == 3);
    ///
    ///     #expect(queue.append(4) == 1);
    ///     #expect(queue.append(5) == 2);
    ///
    ///     #expect(queue.front == 3);
    ///     #expect(queue.back  == 5);
    ///
    /// Will always pass.
    /// - Parameters:
    ///     - value: The value to insert to the queue.
    /// - Returns:
    ///     The oldest value in the queue, if the queue is full. This value is no longer in the queue.

    public mutating func append(_ value: T) -> T? {
        let willReturn = self.isFull
        
        // Obtain our result value
        let oldData = self.data[self.p];
        self.data[self.p] = value;
        
        self.p = (self.p + 1) % self.capacity;
        if !self.isFull {
            self.count += 1
        }
        
        return willReturn ? oldData : nil;
    }
}
extension LimitedQueue : Sendable where T: Sendable { }

/// An iterator that can be used to traverse a `LimitedQueue` as a single sequence.
public struct LimitedQueueIterator<T> : IteratorProtocol {
    private let data: [T].SubSequence
    private var p: Int?;
    private let b: Int?;
    
    fileprivate init(using: LimitedQueue<T>) {
        self.data = using.data[...]
        self.p = using.frontIndex
        self.b = using.backIndex
    }
    
    public typealias Element = T
    
    public mutating func next() -> T? {
        guard let curr = self.p, let last = self.b else {
            return nil
        }
        
        let next = (curr + 1) % self.data.count;
        
        self.p = (curr == last) ? nil : next;
        
        return self.data[curr]
    }
}

extension LimitedQueue : Sequence {
    public typealias Iterator = LimitedQueueIterator<T>;
    
    public func makeIterator() -> LimitedQueueIterator<T> {
        .init(using: self)
    }
}
extension LimitedQueue : Collection {
    public var startIndex: Int {
        0
    }
    public var endIndex: Int {
        self.count
    }
    
    public func index(after i: Int) -> Int {
        i + 1
    }
    
    public subscript(position: Int) -> T {
        _read {
            assert(position >= 0 && position < self.count, "index out of bounds")
            
            let translated = position % self.capacity
            yield self.data[translated]
        }
    }
}
