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

import CryptoKit
import Foundation
import NineAnimatorCommon
import NineAnimatorNativeParsers
import NineAnimatorNativeSources

/// NACoreEngineFlatBundleProvider reads a flat core bundle from either a remote URL or local filesystem.
///
/// The flat bundle format uses the following structure:
///
/// ```
/// Bundle Directory or URL/
/// |- key.pub              # Signed public key used to verify files
/// |- manifest.json        # Bundle manifest file
/// |- manifest.json.sig    # Manifest signature
/// |- services/
///     |- <service>.js
///     |- <service>.js.sig
///     |- ...
/// |- resources/
///     |- <resource>
///     |- <resource>.sig
///     |- ...
/// ```
@available(iOS 13.0, *)
class NACoreEngineFlatBundleProvider: NSObject, NACoreEngineBundleProvider {
    private let bundleUrl: URL
    private let queue: DispatchQueue
    
    init(bundleUrl: URL) {
        self.bundleUrl = bundleUrl
        self.queue = .init(label: "com.marcuszhou.nineanimator.NACoreEngineFlatBundleProvider")
    }
    
    func retrieveBundle() -> NineAnimatorPromise<NACoreEngineBundle> {
        .firstly(queue: self.queue) {
            // Load public key and manifest
            let signingKey = try self.readPublicKey()
            let manifestContent = try self.readSignedContent("manifest.json")
            let manifestDecoder = JSONDecoder()
            
            // Set manifest json decoding policy
            manifestDecoder.keyDecodingStrategy = .convertFromSnakeCase
            
            // Verify manifest signature
            if signingKey.isValidSignature(manifestContent.signature, for: manifestContent.content) {
                let decodedManifest = try manifestDecoder.decode(
                    NACoreEngineBundle.Manifest.self,
                    from: manifestContent.content
                )
                
                return NACoreEngineBundle(
                    decodedManifest,
                    publicKey: signingKey,
                    provider: self
                )
            } else {
                throw NineAnimatorError.decodeError("Unable to verify the signature of the manifest file.")
            }
        }
    }
    
    func loadBundleService(_ service: NACoreEngineBundle.Service, forBundle bundle: NACoreEngineBundle) -> NineAnimatorPromise<NACoreEngineBundle.SignedEvaluable> {
        .firstly(queue: self.queue) {
            let unescapedItemName = try service.path
                .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
                .tryUnwrap()
            let content = try self.readSignedContent("services/\(unescapedItemName)")
            return NACoreEngineBundle.SignedEvaluable(
                content: content.content,
                signature: content.signature,
                sourceUrl: content.url
            )
        }
    }
    
    func loadBundleResource(_ resourcePath: String, forBundle bundle: NACoreEngineBundle) -> NineAnimatorPromise<NACoreEngineBundle.SignedResource> {
        .firstly(queue: self.queue) {
            let unescapedItemName = try resourcePath
                .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
                .tryUnwrap()
            let content = try self.readSignedContent("resources/\(unescapedItemName)")
            return NACoreEngineBundle.SignedResource(content: content.content, signature: content.signature)
        }
    }
    
    private func readPublicKey() throws -> NACoreEngineBundle.SigningKey {
        let keyUrl = self.bundleUrl.appendingPathComponent("key.pub")
        let keyContent = try Data(contentsOf: keyUrl)
        return try .init(rawRepresentation: keyContent)
    }
    
    // swiftlint:disable large_tuple
    // ...yeah, yeah, blah, blah, blah
    private func readSignedContent(_ resourcePath: String) throws -> (content: Data, signature: Data, url: URL) {
        let resourceUrl = bundleUrl.appendingPathComponent(resourcePath)
        let resourceSignatureUrl = bundleUrl.appendingPathComponent(resourcePath + ".sig")
        
        return (
            try Data(contentsOf: resourceUrl),
            try Data(contentsOf: resourceSignatureUrl),
            resourceUrl
        )
    }
    // swiftlint:enable large_tuple
}
