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

import CommonCrypto
import Foundation
import SwiftSoup

extension NASourceKissanime {
    static let knownServers = [
//        "rapidvideo": "RapidVideo",
//        "openload": "OpenLoad",
        "mp4upload": "Mp4Upload",
//        "streamango": "Streamango",
        "nova": "Nova Server",
        "beta": "Beta Server",
        "beta4": "Beta4 Server"
    ]
    
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        NineAnimatorPromise.firstly {
            () -> URL? in
            let episodeRawUrl = try URL(
                string: link.identifier,
                relativeTo: anime.link.link
            ).tryUnwrap()
            var episodeUrlComponents = try URLComponents(
                url: episodeRawUrl,
                resolvingAgainstBaseURL: true
            ).tryUnwrap()
            
            // Rebuild the url with server parameter
            var queryItems = episodeUrlComponents.queryItems ?? []
            queryItems.append(.init(name: "s", value: link.server))
            episodeUrlComponents.queryItems = queryItems
            return episodeUrlComponents.url
        } .thenPromise {
            reconstructedUrl in self
                .request(browseUrl: reconstructedUrl)
                .then { (reconstructedUrl, $0) }
        } .then {
            reconstructedUrl, content in
            let bowl = try SwiftSoup.parse(content)
            
            // Check if an verification is needed to access this page
            if try bowl.select("head>title")
                .text()
                .trimmingCharacters(in: .whitespacesAndNewlines) == "Are You Human" {
                throw NineAnimatorError.authenticationRequiredError(
                    "KissAnime requires you to complete a verification before viewing the episode",
                    reconstructedUrl
                ).withSourceOfError(self)
            }
            
            // Check if the currently loading episode is the selected server
            if try !bowl.select("#selectServer>option[selected]").attr("value").hasSuffix(link.server) {
                throw NineAnimatorError.responseError("This episode is not available on the selected server")
            }
            
            let targetUrl: URL
            var episodeUserInfo = [String: Any]()
            
            // Detect if the video URL is embedded in the page
            let qualitySelectionOptions = try bowl.select("#slcQualix>option")
            if !qualitySelectionOptions.isEmpty() {
                let videoSelections = Dictionary(try qualitySelectionOptions.map {
                    option in (
                        option.ownText().lowercased(),
                        try option.attr("value")
                    )
                }) { $1 }
                let selectedVideoOptionValue = try videoSelections["1080p"]
                    ?? videoSelections["720p"]
                    ?? videoSelections.first.tryUnwrap().value
                let decodedVideoUrlString = try NASourceKissanime.decodeOvel(
                    base64EncodedString: selectedVideoOptionValue
                )
                episodeUserInfo["kissanime.dummy"] = true
                targetUrl = try URL(string: decodedVideoUrlString).tryUnwrap()
            } else {
                let frameMatchingRegex = try NSRegularExpression(
                    pattern: "\\$\\('#divMyVideo'\\)\\.html\\('([^']+)",
                    options: []
                )
                
                let frameScriptSourceMatch = try frameMatchingRegex
                    .firstMatch(in: content)
                    .tryUnwrap(.responseError("Cannot find a valid URL to the resource"))
                    .firstMatchingGroup
                    .tryUnwrap()
                
                let parsedFrameElement = try SwiftSoup.parse(frameScriptSourceMatch).select("iframe")
                let targetLinkString = try parsedFrameElement.attr("src")
                targetUrl = try URL(string: targetLinkString, relativeTo: reconstructedUrl).tryUnwrap()
            }
            
            // Construct the episode object
            return Episode(
                link,
                target: targetUrl,
                parent: anime,
                referer: reconstructedUrl.absoluteString,
                userInfo: episodeUserInfo
            )
        }
    }
    
    /// Infer the episode number from episode name
    func inferEpisodeNumber(fromName name: String) -> Int? {
        do {
            let matchingRegex = try NSRegularExpression(
                pattern: "Episode\\s+(\\d+)",
                options: [.caseInsensitive]
            )
            let episodeNumberMatch = try matchingRegex
                .firstMatch(in: name)
                .tryUnwrap()
                .firstMatchingGroup
                .tryUnwrap()
            let inferredEpisodeNumber = Int(episodeNumberMatch)
            
            // Return the inferred value if it's valid
            if let eNumb = inferredEpisodeNumber, eNumb > 0 {
                return eNumb
            } else { return nil }
        } catch { return nil }
    }
    
    /// Decode kissanime CBC/Pkcs7 encrypted data
    fileprivate static func decodeOvel(base64EncodedString: String) throws -> String {
        let encryptedData = try Data(base64Encoded: base64EncodedString).tryUnwrap(
            .responseError("Invalid base64 parameter")
        )
        let iv = try Data(base64Encoded: "pejS6cFyGuDoStZgxHLB8w==").tryUnwrap()
        let key = try Data(base64Encoded: "/J90X5HuPNXncBpFUPGAbaFdm5iYrZU+gp+cEpmCQ9Y=").tryUnwrap()
        
        let destinationBufferLength = encryptedData.count + kCCBlockSizeAES128
        var destinationBuffer = Data(count: destinationBufferLength)
        var decryptedBytes = 0
        
        // AES256-CBC decrypt with key and iv
        let decryptionStatus = destinationBuffer.withUnsafeMutableBytes {
            destinationPointer in
            encryptedData.withUnsafeBytes {
                dataPointer in
                key.withUnsafeBytes {
                    keyPointer in
                    iv.withUnsafeBytes {
                        ivPointer in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPointer.baseAddress!,
                            kCCKeySizeAES256,
                            ivPointer.baseAddress!,
                            dataPointer.baseAddress!,
                            encryptedData.count,
                            destinationPointer.baseAddress!,
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
        
        return try String(
            data: destinationBuffer,
            encoding: .utf8
        ).tryUnwrap(.responseError("Malformed data"))
         .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    }
}
