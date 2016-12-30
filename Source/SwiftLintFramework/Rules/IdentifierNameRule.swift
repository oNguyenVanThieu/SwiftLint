//
//  IdentifierNameRule.swift
//  SwiftLint
//
//  Created by JP Simard on 5/16/15.
//  Copyright © 2015 Realm. All rights reserved.
//

import Foundation
import SourceKittenFramework

public struct IdentifierNameRule: ASTRule, ConfigurationProviderRule {

    public var configuration = NameConfiguration(minLengthWarning: 3,
                                                 minLengthError: 2,
                                                 maxLengthWarning: 40,
                                                 maxLengthError: 60)

    public init() {}

    public static let description = RuleDescription(
        identifier: "identifier_name",
        name: "Identifier Name",
        description: "Identifier names should only contain alphanumeric characters and " +
            "start with a lowercase character or should only contain capital letters. " +
            "In an exception to the above, variable names may start with a capital letter " +
            "when they are declared static and immutable. Variable names should not be too " +
            "long or too short.",
        nonTriggeringExamples: IdentifierNameRuleExamples.swift3NonTriggeringExamples,
        triggeringExamples: IdentifierNameRuleExamples.swift3TriggeringExamples
    )

    private func nameIsViolatingCase(_ name: String) -> Bool {
        let secondIndex = name.characters.index(after: name.startIndex)
        let firstCharacter = name.substring(to: secondIndex)
        guard firstCharacter.isUppercase() else {
            return false
        }
        guard name.characters.count > 1 else {
            return true
        }
        let range = secondIndex..<name.characters.index(after: secondIndex)
        let secondCharacter = name.substring(with: range)
        return secondCharacter.isLowercase()
    }

    public func validateFile(_ file: File, kind: SwiftDeclarationKind,
                             dictionary: [String: SourceKitRepresentable]) -> [StyleViolation] {
        guard !dictionary.enclosedSwiftAttributes.contains("source.decl.attribute.override") else {
            return []
        }

        return validateName(dictionary, kind: kind).map { name, offset in
            guard !configuration.excluded.contains(name) else {
                return []
            }

            let isFunction = SwiftDeclarationKind.functionKinds().contains(kind)
            let description = type(of: self).description

            let type = typeForKind(kind)
            if !isFunction {
                if !CharacterSet.alphanumerics.isSuperset(ofCharactersIn: name) {
                    return [
                        StyleViolation(ruleDescription: description,
                                       severity: .error,
                                       location: Location(file: file, byteOffset: offset),
                                       reason: "\(type) name should only contain alphanumeric " +
                            "characters: '\(name)'")
                    ]
                }

                if let severity = severity(forLength: name.characters.count) {
                    let reason = "\(type) name should be between " +
                        "\(configuration.minLengthThreshold) and " +
                        "\(configuration.maxLengthThreshold) characters long: '\(name)'"
                    return [
                        StyleViolation(ruleDescription: type(of: self).description,
                                       severity: severity,
                                       location: Location(file: file, byteOffset: offset),
                                       reason: reason)
                    ]
                }
            }

            if kind != .varStatic && nameIsViolatingCase(name) && !isOperator(name: name) {
                let reason = "\(type) name should start with a lowercase character: '\(name)'"
                return [
                    StyleViolation(ruleDescription: description,
                                   severity: .error,
                                   location: Location(file: file, byteOffset: offset),
                                   reason: reason)
                ]
            }

            return []
        } ?? []
    }

    private func isOperator(name: String) -> Bool {
        let operators = ["/", "=", "-", "+", "!", "*", "|", "^", "~", "?", ".", "%", "<", ">", "&"]
        return !operators.filter(name.hasPrefix).isEmpty
    }

    private func validateName(_ dictionary: [String: SourceKitRepresentable],
                              kind: SwiftDeclarationKind) -> (name: String, offset: Int)? {
        let kinds = kindsForSwiftVersion(.current)

        guard let name = dictionary["key.name"] as? String,
            let offset = (dictionary["key.offset"] as? Int64).flatMap({ Int($0) }),
            kinds.contains(kind) && !name.hasPrefix("$") else {
                return nil
        }

        return (name.nameStrippingLeadingUnderscoreIfPrivate(dictionary), offset)
    }

    private func kindsForSwiftVersion(_ version: SwiftVersion) -> [SwiftDeclarationKind] {
        let common = SwiftDeclarationKind.variableKinds() + SwiftDeclarationKind.functionKinds()
        switch version {
        case .two:
            return common
        case .three:
            return common + [.enumelement]
        }
    }

    private func typeForKind(_ kind: SwiftDeclarationKind) -> String {
        if SwiftDeclarationKind.functionKinds().contains(kind) {
            return "Function"
        } else if kind == .enumelement {
            return "Enum element"
        } else {
            return "Variable"
        }
    }
}
