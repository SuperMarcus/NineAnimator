//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018-2020 Marcus Zhou. All rights reserved.
//
//  NineAnimator is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  NineAnimator is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with NineAnimator.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation

// swiftlint:disable large_tuple

/// A string decoder for PACKER packed JavaScript code, which is seen in
/// many streaming sources.
///
/// Thanks [Awesomedude](https://github.com/Awsomedude) for bringing this up.
///
/// ## References
/// 1. [jsunpack.py](https://github.com/jsergio123/script.module.resolveurl/blob/master/lib/resolveurl/plugins/lib/jsunpack.py)
/// 2. [packer.py](https://github.com/beautify-web/js-beautify/blob/master/python/jsbeautifier/unpackers/packer.py)
public struct PackerDecoder {
    /// A regular expression that extracts the decoding parameters from the payload
    private static let parameterExtractionRegex = try! NSRegularExpression(
        pattern: "\\}\\('(.*)',\\s*(\\d+|\\[\\]),\\s*(\\d+),\\s*'(.*)'\\.split\\('\\|'\\)",
        options: []
    )
    
    /// Base lookup table
    private static let lookupTable = Dictionary(
        uniqueKeysWithValues: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".enumerated().map { ($1, $0) }
    )
    
    public init() { }
    
    /// Decode the P.A.C.K.E.R. encoded payload
    public func decode(_ encoded: String) throws -> String {
        let ( payload, radix, tabs ) = try extractArguments(from: encoded)
        let safeReferenceRange = (0..<tabs.count)
        
        // Interate references in payload to tabs
        let iteratedPayload = traverse(payload) {
            reference in
            if let referencingOffset = ord(reference, withRadix: radix, safeRange: safeReferenceRange), !tabs[referencingOffset].isEmpty {
                return tabs[referencingOffset]
            }
            return reference
        }
        
        // Return the resulted payload
        return iteratedPayload
    }
    
    /// Traverse through alphanumeric values
    private func traverse(_ input: String, traverser: (String) -> String) -> String {
        let inclusiveSet = CharacterSet.alphanumerics
        var buildingString = [Unicode.Scalar]()
        var currentComponent = [Unicode.Scalar]()
        
        // Manually iterates through the characters
        // This is more efficient than using regex
        for element in input.unicodeScalars {
            if inclusiveSet.contains(element) {
                currentComponent.append(element)
            } else { // Reached boundary
                // Call the traverser and store the results
                if !currentComponent.isEmpty {
                    let traverseComponent = String(String.UnicodeScalarView(currentComponent))
                    let result = traverser(traverseComponent)
                    buildingString.append(contentsOf: result.unicodeScalars)
                }
                
                // Store the seperator character
                buildingString.append(element)
                
                // Clear the component
                currentComponent = []
            }
        }
        
        // Process the last component
        if !currentComponent.isEmpty {
            let traverseComponent = String(String.UnicodeScalarView(currentComponent))
            let result = traverser(traverseComponent)
            buildingString.append(contentsOf: result.unicodeScalars)
        }
        
        // Assemble the result string
        return String(String.UnicodeScalarView(buildingString))
    }
    
    /// Convert payload string with the given radix to a number
    private func ord(_ payload: String, withRadix radix: Int, safeRange: Range<Int>) -> Int? {
        let lookupTable = PackerDecoder.lookupTable
        var result = 0
        
        // Check if the safe range contains 0
        if !safeRange.contains(result) { return nil }
        
        // Iterate through the payload
        for element in payload {
            // Push digits
            result *= radix
            
            // Obtain the digit from the lookup table
            if let digit = lookupTable[element] {
                result += digit
            }
            
            // Check if the value is still within the safe range
            if !safeRange.contains(result) {
                return nil
            }
        }
        
        // Return the results
        return result
    }
    
    /// Extracting decoding arguments from the encoded string
    private func extractArguments(from encoded: String) throws -> (payload: String, radix: Int, tabs: [String]) {
        // Extract raw parameters
        let matches = try PackerDecoder
            .parameterExtractionRegex
            .firstMatch(in: encoded)
            .tryUnwrap(.providerError("Unable to decode the encoded resource parameters"))
        
        // Extract tabs
        // Not using swift's split because it ignores zero-length parts
        let tabs = matches[4].reduce([""]) {
            list, character in
            var newList = list
            if character == "|" {
                newList.append("")
            } else if let last = newList.popLast() {
                newList.append(last + String(character))
            }
            return newList
        }
        
        // Extracting radix and count
        let radix = try Int(matches[2]).tryUnwrap(.providerError("The responding resource parameters are malformed"))
        let count = try Int(matches[3]).tryUnwrap(.providerError("The responding resource parameters are malformed"))
        
        // Check the number of tabs
        guard count == tabs.count else {
            throw NineAnimatorError.providerError("The responding resource parameters are ambiguous")
        }
        
        return (matches[1], radix, tabs)
    }
}
