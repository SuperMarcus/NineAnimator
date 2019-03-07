//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018-2019 Marcus Zhou. All rights reserved.
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

import CommonCrypto
import Foundation

extension NASourceAnimeTwist {
    fileprivate static let encryptionKey = "k8B$B@0L8D$tDYHGmRg98sQ7!%GOEGOX27T".data(using: .utf8)!
    
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        guard let sourcePool = anime.additionalAttributes["twist.source"] as? [EpisodeLink: String],
            let encryptedSourceString = sourcePool[link],
            let encryptedSource = Data(base64Encoded: encryptedSourceString) else {
            return .fail(NineAnimatorError.providerError("Streaming source cannot be found"))
        }
        
        // Unlike other sources, anime on twist.moe are self-hosted and encrypted.
        // So the major portion of the code here is to decrypt the source and assign
        // it to the targetUrl property.
        return NineAnimatorPromise.firstly {
            // Check if the data has the prefix
            let saltIdentifier = "Salted__"
            guard String(data: encryptedSource[0..<8], encoding: .utf8) == saltIdentifier else {
                throw NineAnimatorError.responseError("Invalid source")
            }
            
            // 8 bytes of salt
            let salt = encryptedSource[8..<16]
            let data = encryptedSource[16...]
            
            // Calculate the key and iv
            let (key, iv) = self.generateKeyAndIV(NASourceAnimeTwist.encryptionKey, salt: salt)
            
            let destinationBufferLength = data.count + kCCBlockSizeAES128
            var destinationBuffer = Data(count: destinationBufferLength)
            var decryptedBytes = 0
            
            // AES256-CBC decrypt with the derived key and iv
            let decryptionStatus = destinationBuffer.withUnsafeMutableBytes {
                destinationPointer in
                data.withUnsafeBytes {
                    dataPointer in
                    key.withUnsafeBytes {
                        keyPointer in
                        iv.withUnsafeBytes {
                            ivPointer in
                            CCCrypt(
                                CCOperation(kCCDecrypt),
                                CCAlgorithm(kCCAlgorithmAES),
                                CCOptions(kCCOptionPKCS7Padding),
                                keyPointer,
                                kCCKeySizeAES256,
                                ivPointer,
                                dataPointer,
                                data.count,
                                destinationPointer,
                                destinationBufferLength,
                                &decryptedBytes
                            )
                        }
                    }
                }
            }
            
            // Check result status
            guard decryptionStatus == CCCryptorStatus(kCCSuccess) else {
                throw NineAnimatorError.responseError("Unable to decrypt video streaming information")
            }
            
            // Convert decrypted path to string
            guard let episodePath = String(data: destinationBuffer[0..<decryptedBytes], encoding: .utf8) else {
                throw NineAnimatorError.responseError("Video streaming information is corrupted")
            }
            
            // Construct episode target url
            let episodeUrl = self.endpointURL.appendingPathComponent(episodePath)
            Log.info("[twist.moe] Decrypted video URL at %@", episodeUrl.absoluteString)
            
            // Construt Episode struct
            return Episode(link, target: episodeUrl, parent: anime)
        }
    }
    
    /// Derives the 32-byte AES key and the 16-byte IV from data and salt
    ///
    /// See OpenSSL's implementation of EVP_BytesToKey
    private func generateKeyAndIV(_ data: Data, salt: Data) -> (key: Data, iv: Data) {
        let totalLength = 48
        var destinationBuffer = Data(capacity: totalLength)
        let dataAndSalt = data + salt
        
        // Calculate the key and value with data and salt
        var digestBuffer = Data(count: Int(CC_MD5_DIGEST_LENGTH))
        _ = digestBuffer.withUnsafeMutableBytes {
            destinationPointer in
            dataAndSalt.withUnsafeBytes {
                pointer in
                CC_MD5(pointer, CC_LONG(dataAndSalt.count), destinationPointer)
            }
        }
        destinationBuffer.append(digestBuffer)
        
        // Keep digesting until the buffer is filled
        while destinationBuffer.count < totalLength {
            let combined = digestBuffer + dataAndSalt
            _ = digestBuffer.withUnsafeMutableBytes {
                destinationPointer in
                combined.withUnsafeBytes {
                    pointer in
                    CC_MD5(pointer, CC_LONG(combined.count), destinationPointer)
                }
            }
            destinationBuffer.append(digestBuffer)
        }
        
        // Generate key and iv
        return (destinationBuffer[0..<32], destinationBuffer[32..<48])
    }
}
