//
//  ValueWrapperField.swift
//  Edmund
//
//  Created by Hollan Sellars on 7/2/25.
//

import SwiftUI

public struct NumericalValueEntry<F, Label> : View where F: ParseableFormatStyle, F.FormatOutput == String, Label: View {
    public init(value: Binding<F.FormatInput>, format: F, @ViewBuilder label: @escaping () -> Label) {
        self._value = value;
        self.format = format;
        self.text = format.format(value.wrappedValue);
        self.label = label;
    }
    
    
    @Binding public var value: F.FormatInput;
    @State private var text: String;
    public let format: F;
    public let label: () -> Label;
    
    @FocusState private var focus: Bool;
    
    public var body: some View {
        TextField(text: $text, label: label)
            .textFieldStyle(.roundedBorder)
            .onSubmit {
                self.text = format.format(value)
            }
            .onChange(of: text) { _, raw in
                let filter = raw.filter { "-0123456789.".contains($0) }
                
                guard let parsed = try? format.parseStrategy.parse(filter) else {
                    return;
                }
                
                self.value = parsed;
            }
            .focused($focus)
            .onChange(of: focus) { _, newValue in
                if !newValue {
                    self.text = format.format(value)
                }
            }
    }
}
extension NumericalValueEntry where Label == EmptyView {
    public init(value: Binding<F.FormatInput>, format: F) {
        self.init(value: value, format: format, label: { EmptyView() } )
    }
}
extension NumericalValueEntry where Label == Text {
    public init(value: Binding<F.FormatInput>, format: F, label: LocalizedStringKey) {
        self.init(
            value: value,
            format: format,
            label: {
                Text(label)
            })
    }
}

extension NumericalValueEntry where F == Decimal.FormatStyle.Currency {
    public init(_ currencyValue: Binding<Decimal>, currencyCode: String, locale: Locale = Locale.current, @ViewBuilder label: @escaping () -> Label) {
        self.init(
            value: currencyValue,
            format: .currency(code: currencyCode).locale(locale),
            label: label
        )
    }
}
extension NumericalValueEntry where F == Decimal.FormatStyle.Currency, Label == EmptyView {
    public init(_ currencyValue: Binding<Decimal>, currencyCode: String, locale: Locale = Locale.current) {
        self.init(
            value: currencyValue,
            format: .currency(code: currencyCode).locale(locale)
        )
    }
}
extension NumericalValueEntry where F == Decimal.FormatStyle.Currency, Label == Text {
    public init(_ currencyValue: Binding<Decimal>, currencyCode: String, locale: Locale = Locale.current, label: LocalizedStringKey) {
        self.init(
            value: currencyValue,
            format: .currency(code: currencyCode).locale(locale),
            label: label
        )
    }
}

extension NumericalValueEntry where F == Decimal.FormatStyle.Percent {
    public init(_ percentValue: Binding<Decimal>, precision: Int = 2, @ViewBuilder label: @escaping () -> Label) {
        self.init(
            value: percentValue,
            format: .percent.precision(.fractionLength(3)),
            label: label
        )
    }
}
extension NumericalValueEntry where F == Decimal.FormatStyle.Percent, Label == EmptyView {
    public init(_ percentValue: Binding<Decimal>, precision: Int = 2) {
        self.init(
            value: percentValue,
            format: .percent.precision(.fractionLength(3))
        )
    }
}
extension NumericalValueEntry where F == Decimal.FormatStyle.Percent, Label == Text {
    public init(_ percentValue: Binding<Decimal>, precision: Int = 2, label: LocalizedStringKey) {
        self.init(
            value: percentValue,
            format: .percent.precision(.fractionLength(3)),
            label: label
        )
    }
}

public typealias CurrencyField<Label> = NumericalValueEntry<Decimal.FormatStyle.Currency, Label> where Label: View;
public typealias PercentField<Label> = NumericalValueEntry<Decimal.FormatStyle.Percent, Label> where Label: View;
