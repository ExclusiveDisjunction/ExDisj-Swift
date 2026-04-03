//
//  ValidationFailure.swift
//  Edmund
//
//  Created by Hollan Sellars on 6/29/25.
//

import SwiftUI

public protocol ValidatableFields : CustomStringConvertible, CaseIterable, Identifiable, Sendable, Hashable where Self.ID == Self { }

/// A failure to validate a value out of a snapshot/element.
public enum ValidationFailureReason: Sendable, Error, Hashable {
    public enum AmountDirection : Sendable {
        case tooLarge
        case tooSmall
    }
    
    /// A uniqueness check failed over a set of identifiers.
    case unique
    /// A field was empty
    case empty
    /// A field was negative
    case negativeAmount
    case amount(direction: AmountDirection, relativeTo: String)
    case stringLength(direction: AmountDirection, relativeTo: Int)
    case elementValidation(String)
    /// A field has invalid input
    case invalidInput
    ///Happens when there is an internal expection that failed
    case internalError
    
    public var id: Self { self }
}

public protocol ValidationBuilderProtocol : ~Copyable, Sendable {
    associatedtype Fields: ValidatableFields;
    
    mutating func add(prop: Fields, reason: ValidationFailureReason)
}
extension ValidationBuilderProtocol where Self: ~Copyable {
    public mutating func check<S>(prop: Fields, text: S?, trimming: CharacterSet? = .whitespacesAndNewlines) where S: StringProtocol {
        guard let text else {
            return; //Assumed to not matter
        }
        
        if let trimming, text.trimmingCharacters(in: trimming).isEmpty {
            self.add(prop: prop, reason: .empty)
        }
        else if text.isEmpty {
            self.add(prop: prop, reason: .empty)
        }
    }
    public mutating func check<S>(prop: Fields, text: S, lengthMin: Int = 0, lengthMax: Int? = nil) where S: StringProtocol {
        if text.count < lengthMin {
            self.add(prop: prop, reason: .stringLength(direction: .tooSmall, relativeTo: lengthMin))
        }
        
        if let lengthMax, text.count > lengthMax {
            self.add(prop: prop, reason: .stringLength(direction: .tooLarge, relativeTo: lengthMax))
        }
    }
    public mutating func check<T>(prop: Fields, value: T, min: T? = nil, max: T? = nil) where T: Comparable & CustomStringConvertible {
        if let min, value < min {
            self.add(prop: prop, reason: .amount(direction: .tooSmall, relativeTo: min.description))
        }
        if let max, value > max {
            self.add(prop: prop, reason: .amount(direction: .tooLarge, relativeTo: max.description))
        }
    }
    public mutating func check(prop: Fields, startDate: Date, endDate: Date?, ignoreTime: Bool, calendar: Calendar) {
        let startDate = ignoreTime ? calendar.startOfDay(for: startDate) : startDate;
        if let endDate {
            let properEndDate = ignoreTime ? calendar.startOfDay(for: endDate) : endDate;
            
            if startDate >= properEndDate {
                self.add(prop: prop, reason: .invalidInput)
            }
        }
    }
    public mutating func check<T>(prop: Fields, nonNegative: T) where T: BinaryInteger {
        if nonNegative < 0 {
            self.add(prop: prop, reason: .negativeAmount)
        }
    }
    public mutating func check<T>(prop: Fields, nonNegative: T) where T: BinaryFloatingPoint {
        if nonNegative < 0 {
            self.add(prop: prop, reason: .negativeAmount)
        }
    }
    public mutating func check(prop: Fields, nonNegative: Decimal) {
        if nonNegative < 0 {
            self.add(prop: prop, reason: .negativeAmount)
        }
    }
    public mutating func check<T>(prop: Fields, nonZero: T) where T: BinaryInteger {
        if nonZero == 0 {
            self.add(prop: prop, reason: .invalidInput)
        }
    }
    public mutating func check<T>(prop: Fields, nonZero: T) where T: BinaryFloatingPoint {
        if nonZero == 0 {
            self.add(prop: prop, reason: .invalidInput)
        }
    }
    public mutating func check(prop: Fields, nonZero: Decimal) {
        if nonZero == 0 {
            self.add(prop: prop, reason: .invalidInput)
        }
    }
    public mutating func check<T>(prop: Fields, nonNil: T?, processRequired: Bool, performing: (T) -> Void) {
        if let nonNil {
            performing(nonNil)
        }
        else {
            if processRequired {
                self.add(prop: prop, reason: .internalError)
            }
            else {
                self.add(prop: prop, reason: .empty)
            }
        }
    }
    
    public mutating func check<ID>(prop: Fields, oldId: ID, newId: ID, isUnique: (ID) throws -> Bool) rethrows
    where ID: Equatable {
        if oldId != newId {
            let result = try isUnique(newId);
            if !result {
                self.add(prop: prop, reason: .unique)
            }
        }
    }
    public mutating func check<ID>(prop: Fields, oldId: ID, newId: ID, isUnique: (ID) async throws -> Bool) async rethrows
    where ID: Equatable {
        if oldId != newId {
            let result = try await isUnique(newId);
            if !result {
                self.add(prop: prop, reason: .unique)
            }
        }
    }
}

/// A user-based failure that indicates that there are problems with individual properties.
public struct ValidationFailure<Fields> : Sendable, Error where Fields: ValidatableFields {
    public init(_ grievences: [Fields : ValidationFailureReason]) {
        self.grievences = grievences;
        self.message = Self.buildMessage(grievences);
    }
    
    /// Builds the message from the properties and failures, using localization.
    private static func buildMessage(_ grievences: [Fields: ValidationFailureReason]) -> String {
        let header = "Please fix the following issues:\n";
        
        var lines: [String] = [];
        for (prop, reason) in grievences {
            let propName = prop.description;
            let fragment = switch reason {
                case .empty: "cannot be empty"
                case .invalidInput: "is invalid"
                case .negativeAmount: "cannot be negative"
                case .amount(let direction, let relativeTo):
                    switch direction {
                        case .tooLarge: "is too large, it must be less than \(relativeTo)"
                        case .tooSmall: "is too small, it must be at least \(relativeTo)"
                    }
                case .stringLength(let direction, let relativeTo):
                    switch direction {
                        case .tooLarge: "is too long, it must be less than \(relativeTo) characters"
                        case .tooSmall: "is too short, it must be at least \(relativeTo) characters"
                    }
                case .unique: "must be unique"
                case .internalError: "had an internal error"
                case .elementValidation(let msg): msg
            };
            
            let line = "\"\(propName)\" \(fragment)";
            lines.append(line)
        }
        
        let joinedLines = lines.joined(separator: "\n");
        
        return header + joinedLines;
    }
    
    /// The failures reported.
    public let grievences: [Fields: ValidationFailureReason];
    /// The message to present to the UI.
    public let message: String;
    
    
    
    public struct ElementsBuilder<F> : ~Copyable, Sendable, ValidationBuilderProtocol
    where F: ValidatableFields
    {
        public init() {
            observed = [:];
        }
        
        public typealias Fields = F
        public private(set) var observed: Dictionary<ValidationFailureReason, Set<F>>;
        
        
        public mutating func add(prop: F, reason: ValidationFailureReason) {
            observed[reason, default: Set()].insert(prop)
        }
        
        fileprivate consuming func build() -> String? {
            guard !self.observed.isEmpty else {
                return nil;
            }
            
            /*
                Please ensure ..., ...., and ....
                (Properties...) is ...
             */
            
            var resulting: [String] = [];
            for (reason, properties) in observed {
                guard !properties.isEmpty else {
                    continue
                }
                guard reason != .internalError else {
                    return InternalErrorWarning.internalError;
                }
                
                var partialResult = "";
                partialResult.append(
                    properties.map { $0.description }.joined(separator: ", ")
                )
                partialResult += " is"
                switch reason {
                    case .empty: partialResult += "not empty"
                    case .invalidInput: partialResult += "valid"
                    case .stringLength(let direction, let relativeTo):
                        switch direction {
                            case .tooLarge: "less than, or equal to \(relativeTo) in length"
                            case .tooSmall: "at least \(relativeTo) characters"
                        }
                    case .negativeAmount: "not negative"
                    case .internalError: fatalError()
                    case .unique: "unique"
                    case .amount(let direction, let relativeTo):
                        switch direction {
                            case .tooLarge: "less than, or equal to \(relativeTo)"
                            case .tooSmall: "is at least \(relativeTo)"
                        }
                    case .elementValidation(let msg): msg
                }
            }
            
            switch resulting.count {
                case 0: return nil
                case 1: return resulting[0]
                default:
                    var last = resulting.popLast()!;
                    last = "and " + last;
                    resulting.append(last);
                    
                    return resulting.joined(separator: ", ");
            }
        }
    }
    
    public struct Builder : ~Copyable, Sendable, ValidationBuilderProtocol {
        /// Constructs the builder with no intial failures.
        public init() {
            self.grievences = [:];
        }
        
        /// The issues observed as a series of property names and ``ValidationFailureReason``.
        public var grievences: [Fields : ValidationFailureReason];
        
        /// Adds a new failure.
        /// - Parameters:
        ///     - prop: The property the issue was observed with
        ///     - reason: The ``ValidationFailureReason`` observed with the property.
        public mutating func add(prop: Fields, reason: ValidationFailureReason) {
            self.grievences[prop] = reason;
        }
        
        public mutating func checkChildren<C, F>(prop: Fields, forFields: F.Type = F.self, data: C, performing: (C.Element, inout ElementsBuilder<F>) throws -> Void) rethrows
        where C: Collection,
              F: ValidatableFields
        {
            var builder = ElementsBuilder<F>();
            for item in data {
                try performing(item, &builder);
            }
            
            if let msg = builder.build() {
                self.add(prop: prop, reason: .elementValidation(msg))
            }
        }
        public mutating func checkChildren<C, F>(prop: Fields, forFields: F.Type = F.self, data: C, performing: (C.Element, inout ElementsBuilder<F>) async throws -> Void) async rethrows
        where C: Collection,
              F: ValidatableFields
        {
            var builder = ElementsBuilder<F>();
            for item in data {
                try await performing(item, &builder);
            }
            
            if let msg = builder.build() {
                self.add(prop: prop, reason: .elementValidation(msg))
            }
        }
        
        /// Builds the failures together into a ``ValidationFailure`` if any issues were observed.
        /// - Returns: The ``ValidationFailure`` containing the issues. If no issues were reported, this will return `nil`.
        public consuming func build() -> ValidationFailure<Fields>? {
            if self.grievences.isEmpty {
                return nil;
            } else {
                return ValidationFailure(self.grievences);
            }
        }
    }
    
    public static func withValidationCheck(performing: (inout Builder) -> Void) throws(ValidationFailure<Fields>) {
        var builder = Builder();
        performing(&builder);
        
        if let built = builder.build() {
            throw built;
        }
    }
    public static func withValidationCheck(performing: (inout Builder) async -> Void) async throws(ValidationFailure<Fields>) {
        var builder = Builder();
        await performing(&builder);
        
        if let built = builder.build() {
            throw built;
        }
    }
    public static func withValidationCheck(performing: (inout Builder) throws -> Void) throws {
        var builder = Builder();
        try performing(&builder);
        
        if let built = builder.build() {
            throw built;
        }
    }
    public static func withValidationCheck(performing: (inout Builder) async throws -> Void) async throws {
        var builder = Builder();
        try await performing(&builder);
        
        if let built = builder.build() {
            throw built;
        }
    }
}
@available(*, deprecated, message: "Use ValidationManifest<F>, which provides UI interaction")
extension ValidationFailure : WarningBasis { }

@Observable
public class ValidationManifest<F> where F: ValidatableFields {
    public init() {
        _warning = nil;
        isShowing = false;
    }
    
    private var _warning: ValidationFailure<F>?;
    public var warning: ValidationFailure<F>? {
        get { _warning }
        set {
            _warning = newValue;
            isShowing = newValue != nil;
        }
    }
    public var isShowing: Bool;
    
    @discardableResult
    public func withValidationGuard(performing: (inout ValidationFailure<F>.Builder) -> Void) -> Bool {
        do {
            try ValidationFailure<F>.withValidationCheck(performing: performing);
            self.warning = nil;
            return true;
        }
        catch let e {
            self.warning = e;
            return false;
        }
    }
    @discardableResult
    public func withValidationGuard(performing: (inout ValidationFailure<F>.Builder) throws -> Void) throws -> Bool {
        do {
            try ValidationFailure<F>.withValidationCheck(performing: performing);
            self.warning = nil;
            return true;
        }
        catch let e as ValidationFailure<F> {
            self.warning = e;
            return false;
        }
    }
    @discardableResult
    public func withValidationGuard(performing: (inout ValidationFailure<F>.Builder) async -> Void) async -> Bool{
        do {
            try await ValidationFailure<F>.withValidationCheck(performing: performing);
            self.warning = nil;
            return true;
        }
        catch let e {
            self.warning = e;
            return false;
        }
    }
    @discardableResult
    public func withValidationGuard(performing: (inout ValidationFailure<F>.Builder) async throws -> Void) async throws -> Bool{
        do {
            try await ValidationFailure<F>.withValidationCheck(performing: performing);
            self.warning = nil;
            return true;
        }
        catch let e as ValidationFailure<F> {
            self.warning = e;
            return false;
        }
    }
}

fileprivate struct ValidatableFieldModifier<Fields> : ViewModifier where Fields: ValidatableFields {
    let fields: [Fields];
    @Bindable var manifest: ValidationManifest<Fields>;
    
    private var hasFailed: Bool {
        guard let warning = manifest.warning else {
            return false;
        }
        
        for key in fields {
            guard warning.grievences[key] == nil else {
                return true;
            }
        }
    
        return false;
    }
    
    func body(content: Content) -> some View {
        content
            .padding(hasFailed ? 3 : 0)
            .border(hasFailed ? Color.red : Color.clear)
    }
}

fileprivate struct WithValidationManifest<F> : ViewModifier where F: ValidatableFields {
    @Bindable var manifest: ValidationManifest<F>;
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: $manifest.isShowing) {
                OkButton()
            } message: {
                Text(verbatim: manifest.warning?.message ?? InternalErrorWarning.internalError)
            }
    }
}

extension View {
    public func withWarning<F>(_ manifest: ValidationManifest<F>) -> some View {
        self
            .modifier(WithValidationManifest(manifest: manifest))
    }
    
    @ViewBuilder
    public func validatableField<F>(_ fields: F..., manifest: ValidationManifest<F>?) -> some View
    where F: ValidatableFields {
        if let manifest {
            self
                .modifier(ValidatableFieldModifier(fields: fields, manifest: manifest))
        }
        else {
            self
        }
    }
}

fileprivate enum TestingValidation : ValidatableFields {
    case field1
    
    var id: Self { self }
    var description: String {
        switch self {
            case .field1: "Field 1"
        }
    }
    
    static func validate(name: String) throws(ValidationFailure<TestingValidation>) {
        try ValidationFailure<TestingValidation>.withValidationCheck { build in
            let newName = name.trimmingCharacters(in: .whitespacesAndNewlines);
            if newName.isEmpty {
                build.add(prop: .field1, reason: .empty)
            }
        }
    }
}

#Preview {
    @Previewable @State var manifest: ValidationManifest<TestingValidation> = .init();
    @Previewable @State var text: String = "";
    
    Form {
        TextField("Field 1", text: $text)
            .validatableField(.field1, manifest: manifest)
        
        Button("Submit") {
            manifest.withValidationGuard { builder in
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    builder.add(prop: .field1, reason: .empty)
                }
            }
        }
    }.padding()
}
