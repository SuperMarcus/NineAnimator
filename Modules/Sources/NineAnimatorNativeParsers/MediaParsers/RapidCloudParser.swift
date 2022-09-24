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

import Alamofire
import CommonCrypto
import CryptoKit
import Foundation
import NineAnimatorCommon
import SwiftSoup

/// Server playback asset parser for RapidCloud
class RapidCloudParser: VideoProviderParser {
    var aliases: [String] { [ "RapidCloud", "Rapid Cloud", "rapidcloud" ] }
    
    private let recaptchaSiteKeyRegex = try! NSRegularExpression(
        pattern: #"recaptchaSiteKey\s?=\s'([^']+)"#,
        options: []
    )
    private let recaptchaNumberRegex = try! NSRegularExpression(
        pattern: #"recaptchaNumber\s?=\s'([^']+)"#,
        options: []
    )
    
    private static let apiBaseSourceURL = URL(string: "https://rapid-cloud.co/ajax/embed-6/getSources")!
    
    private static let localeLanguageList: [(name: String, code: String)] = {
        // Zoro.to seems to lists all locales in english
        let englishLocale = NSLocale(localeIdentifier: "en_US")
        let allLocaleList = NSLocale.availableLocaleIdentifiers.map {
            NSLocale(localeIdentifier: $0)
        } .compactMap {
            if let localeDisplay = englishLocale.localizedString(forLanguageCode: $0.localeIdentifier) {
                return (localeDisplay, $0.localeIdentifier)
            }
            return nil
        }
        let deduplicatedLocaleList = Dictionary(allLocaleList) {
            // Use the shortest language code
            $0.count < $1.count ? $0 : $1
        }
        
        return deduplicatedLocaleList.map {
            (name: $0.key, code: $0.value)
        }
    }()
    
    private static var encryptionKey: Data?
    
    private var webSocket: URLSessionWebSocketTask?
    private var semaphore = DispatchSemaphore(value: 0)
    private var sid: String = ""
    private var timer: Timer?
    
    func parse(episode: Episode, with session: Session, forPurpose purpose: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
        NineAnimatorPromise {
            callback in session.request(
                episode.target,
                headers: [
                    "referer": episode.parentLink.link.absoluteString,
                    "user-agent": self.defaultUserAgent
                ]
            ) .responseString {
                callback($0.value, $0.error)
            }
        } .thenPromise {
            responseContent -> NineAnimatorPromise<(String, Data)> in
            self.locateEncryptionKey(
                responseContent,
                frameUrl: episode.target,
                session: session
            ) .then {
                key in (responseContent, key)
            }
        } .thenPromise {
            (responseContent: String, encryptionKey: Data) -> NineAnimatorPromise<(SourcesAPIResponse, AdditionalResourceInfo)> in
            let recaptchaSiteKey = self.recaptchaSiteKeyRegex
                .firstMatch(in: responseContent)?
                .firstMatchingGroup
            let recaptchaNumber = self.recaptchaNumberRegex
                .firstMatch(in: responseContent)?
                .firstMatchingGroup
            
            if let recaptchaNumber, let recaptchaSiteKey {
                Log.debug("[RapidCloudParser] Found reCaptcha keys, proceeding with authenticated requests.")
                return self.proceed(
                    session,
                    withProtectedRequest: episode.target,
                    recaptchaSiteKey: recaptchaSiteKey,
                    recaptchaNumber: recaptchaNumber,
                    requestPurpose: purpose,
                    encryptionKey: encryptionKey
                )
            } else {
                return self.proceed(
                    session,
                    withUnprotectedRequest: episode.target,
                    requestPurpose: purpose,
                    encryptionKey: encryptionKey
                )
            }
        } .then {
            (decodedResponse: SourcesAPIResponse, resourceInfo: AdditionalResourceInfo) -> PlaybackMedia in
            let selectedSource = try decodedResponse
                .sources
                .first
                .tryUnwrap(.providerError("No available source was found"))
            let resourceUrl = try URL(string: selectedSource.file).tryUnwrap(.urlError)
            
            Log.info("[RapidCloudParser] found asset at %@", resourceUrl.absoluteString)
            
            let subtitles = decodedResponse.tracks.compactMap {
                track -> CompositionalPlaybackMedia.SubtitleComposition? in
                if track.kind == "captions",
                   let trackFile = track.file,
                   let trackUrl = URL(string: trackFile) {
                    return .init(
                        url: trackUrl,
                        name: track.label ?? "Unknown",
                        language: self.findLanguageCode(for: track.label ?? "Unknown"),
                        default: track.default == true,
                        autoselect: track.default == true
                    )
                }
                
                return nil
            }
            
            var requestHeaders = [
                "origin": "https://rapid-cloud.co/",
                "referer": "https://rapid-cloud.co/",
                "user-agent": self.defaultUserAgent
            ]
            
            if let requestSid = resourceInfo.sid {
                requestHeaders["SID"] = requestSid
            }
            
            if subtitles.isEmpty {
                return BasicPlaybackMedia(
                    url: resourceUrl,
                    parent: episode,
                    contentType: "application/vnd.apple.mpegurl",
                    headers: requestHeaders,
                    isAggregated: true
                )
            } else {
                return CompositionalPlaybackMedia(
                    url: resourceUrl,
                    parent: episode,
                    contentType: "application/vnd.apple.mpegurl",
                    headers: requestHeaders,
                    subtitles: subtitles
                )
            }
        } .handle(handler)
    }
    
    private func findLanguageCode(for localeName: String) -> String {
        Self.localeLanguageList.first {
            localeName.contains($0.name)
        }?.code ?? localeName
    }
    
    private func locateEncryptionKey(_ frameContent: String, frameUrl: URL, session: Session) -> NineAnimatorPromise<Data> {
        NineAnimatorPromise<URLRequest>.firstly {
            let resourceUrl = try URL(string: "https://raw.githubusercontent.com/consumet/rapidclown/main/key.txt?ts=\(Date().timeIntervalSince1970)")
                .tryUnwrap()
            var request = try URLRequest(url: resourceUrl, method: .get)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            return request
        } .thenPromise {
            (urlRequest: URLRequest) in .init {
                callback in session.request(urlRequest).responseData {
                    callback($0.value, $0.error)
                }
            }
        } .then {
            encryptionKey in
            Self.encryptionKey = encryptionKey
            return encryptionKey
        }
    }
    
    private func proceed(
        _ session: Session,
        withUnprotectedRequest iframeUrl: URL,
        requestPurpose: Purpose,
        encryptionKey: Data
    ) -> NineAnimatorPromise<(SourcesAPIResponse, AdditionalResourceInfo)> {
        NineAnimatorPromise.firstly {
            try Self.extractResourceID(from: iframeUrl)
        } .thenPromise {
            resourceIdentifer in NineAnimatorPromise<SourcesAPIResponse> {
                callback in session.request(
                    RapidCloudParser.apiBaseSourceURL,
                    parameters: [
                        "id": resourceIdentifer
                    ],
                    headers: [
                        "referer": iframeUrl.absoluteString,
                        "x-requested-with": "XMLHttpRequest",
                        "user-agent": self.defaultUserAgent,
                        "accept": "*/*",
                        "accept-language": "en-US,en;q=0.5",
                        "Connection": "keep-alive",
                        "te": "trailers"
                    ]
                ) .responseDecodable(of: SourcesAPIResponse.self) {
                    callback($0.value, $0.error)
                }
            }
        } .then {
            decodedResponse in
            let resourceInfo = AdditionalResourceInfo(
                sid: self.initiateWebSocket(forPurpose: requestPurpose),
                encryptionKey: encryptionKey
            )
            return (decodedResponse, resourceInfo)
        }
    }
    
    private func proceed(
        _ session: Session,
        withProtectedRequest iframeUrl: URL,
        recaptchaSiteKey: String,
        recaptchaNumber: String,
        requestPurpose: Purpose,
        encryptionKey: Data
    ) -> NineAnimatorPromise<(SourcesAPIResponse, AdditionalResourceInfo)> {
        CaptchaSolver().getTokenRecaptcha(
            with: session,
            recaptchaSiteKey: recaptchaSiteKey,
            url: iframeUrl
        ) .thenPromise {
            token in
            let resourceIdentifer = try Self.extractResourceID(from: iframeUrl)
            let sid = self.initiateWebSocket(forPurpose: requestPurpose)
            let resourceInfo = AdditionalResourceInfo(sid: sid, encryptionKey: encryptionKey)
            
            return NineAnimatorPromise<SourcesAPIResponse> {
                callback in session.request(
                    RapidCloudParser.apiBaseSourceURL,
                    parameters: [
                        "id": resourceIdentifer,
                        "_token": token,
                        "_number": recaptchaNumber,
                        "sId": sid
                    ],
                    headers: [
                        "referer": iframeUrl.absoluteString,
                        "x-requested-with": "XMLHttpRequest",
                        "user-agent": self.defaultUserAgent,
                        "accept": "*/*",
                        "accept-language": "en-US,en;q=0.5",
                        "Connection": "keep-alive"
                    ]
                ) .responseDecodable(of: SourcesAPIResponse.self) {
                    callback($0.value, $0.error)
                }
            } .then {
                ($0, resourceInfo)
            }
        }
    }
    
    private static func extractResourceID(from iframeUrl: URL) throws -> String {
        guard iframeUrl.pathComponents.count == 3 else {
            throw NineAnimatorError.providerError("Unexpected iframe URL format")
        }
        
        return try iframeUrl.pathComponents.last.tryUnwrap()
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        // Not suitable for download/cast as difficult to cancel websocket
        return purpose == .playback
    }
}

// MARK: - Request Helpers
private extension RapidCloudParser {
    private static let socketUrl = "wss://ws1.rapid-cloud.co/socket.io/?EIO=4&transport=websocket"
    private static let sidRegex =  try! NSRegularExpression(
        pattern: #"\"sid\":\"(.+?)\""#,
        options: .caseInsensitive
    )
    
    @objc private func onPlaybackDidEnd(_ notification: Notification) {
        DispatchQueue.global().async { [weak self] in self?.disconnect() }
    }
    
    private func initiateWebSocket(forPurpose purpose: Purpose) -> String {
        Log.info("[RapidCloudParser] Websocket session started")
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onPlaybackDidEnd(_:)),
            name: .playbackDidEnd,
            object: nil
        )
        
        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: URL(string: RapidCloudParser.socketUrl)!)
        webSocket?.resume()
        
        ping()
        receive()
        send(text: "40")
        _ = semaphore.wait(timeout: .now() + 5)
        
        if purpose != .playback {
            // Disconnect after 1/2 an hour, if socket is still alive
            DispatchQueue.main.async {
                self.timer?.invalidate()
                self.timer = Timer.scheduledTimer(
                    timeInterval: 1800,
                    target: self,
                    selector: #selector(self.disconnect),
                    userInfo: nil,
                    repeats: false
                )
            }
        }
        
        return sid
    }
    
    private func receive() {
        if webSocket != nil {
            webSocket?.receive { [weak self] result in
                switch result {
                case .failure(let error):
                    Log.error("[RapidCloudParser] Websocket receive error %@", error)
                    self?.disconnect()
                case .success(let message):
                    switch message {
                    case .data(let data): Log.info("[RapidCloudParser] Websocket receive data %@", data)
                    case .string(let message):
                        if message.starts(with: "40") {
                            self?.sid = RapidCloudParser.sidRegex.firstMatch(in: message)?.firstMatchingGroup ?? ""
                            self?.semaphore.signal()
                        } else if message == "2" {
                            self?.send(text: "3")
                        }
                    @unknown default:
                        break
                    }
                    self?.receive()
                }
            }
        }
    }
    
    private func send(text: String) {
        if webSocket != nil {
            let message = URLSessionWebSocketTask.Message.string(text)
            webSocket?.send(message) { error in
                if let error = error {
                    Log.error("[RapidCloudParser] Websocket send error %@", error)
                }
            }
        }
    }
    
    private func ping() {
        if webSocket != nil {
            webSocket?.sendPing { error in
                if let error = error {
                    Log.error("[RapidCloudParser] Websocket ping error %@", error)
                } else {
                    // Websocket connect still alive
                    DispatchQueue.global().asyncAfter(deadline: .now() + 10) { [weak self] in
                        self?.ping()
                    }
                }
            }
        }
    }
    
    @objc private func disconnect() {
        Log.info("[RapidCloudParser] Websocket session ended")
        webSocket?.cancel(with: .goingAway, reason: "Connection ended".data(using: .utf8))
        webSocket = nil
    }
}

// MARK: - Request-Releated Structs
private extension RapidCloudParser {
    struct SourcesAPIResponse: Decodable {
        var encrypted: Bool
        var sources: [Source]
        var tracks: [Track]
    }
    
    struct Source: Decodable {
        var file: String
        var type: String
    }
    
    struct Track: Decodable {
        var file: String?
        var kind: String
        var label: String?
        var `default`: Bool?
    }
    
    struct AdditionalResourceInfo {
        var sid: String?
        var encryptionKey: Data
    }
}

private extension RapidCloudParser.SourcesAPIResponse {
    enum CodingKeys: String, CodingKey {
        case encrypted
        case sources
        case tracks
    }
    
    init(from decoder: Decoder) throws {
        let keyedContainer = try decoder.container(keyedBy: CodingKeys.self)
        let sourcesEncrypted = try keyedContainer.decode(Bool.self, forKey: .encrypted)
        
        self.encrypted = sourcesEncrypted
        self.tracks = try keyedContainer.decode([RapidCloudParser.Track].self, forKey: .tracks)
        
        if sourcesEncrypted {
            guard let encryptionKey = RapidCloudParser.encryptionKey else {
                throw NineAnimatorError.providerError("Sources are encrypted but the encryption key hasn't been loaded.")
            }
            
            let encryptedSourcesString = try keyedContainer.decode(String.self, forKey: .sources)
            let encryptedSourcesData = try Data(base64Encoded: encryptedSourcesString).tryUnwrap()
            let decryptedSourcesData = try RapidCloudParser.decrypt(
                encryptedSourcesData,
                withKey: encryptionKey
            )
            let internalDecoder = JSONDecoder()
            
            self.sources = try internalDecoder.decode(
                [RapidCloudParser.Source].self,
                from: decryptedSourcesData
            )
        } else {
            self.sources = try keyedContainer.decode(
                [RapidCloudParser.Source].self,
                forKey: .sources
            )
        }
    }
}

// Standard CryptoJS.AES functions
private extension RapidCloudParser {
    /// Derives the 32-byte AES key and the 16-byte IV from data and salt
    ///
    /// See OpenSSL's implementation of EVP_BytesToKey
    private static func generateKeyAndIV(_ data: Data, salt: Data) -> (key: Data, iv: Data) {
        let totalLength = 48
        var destinationBuffer = Data(capacity: totalLength)
        let dataAndSalt = data + salt
        
        // Calculate the key and value with data and salt
        var digestBuffer = insecureHash(input: dataAndSalt)
        destinationBuffer.append(digestBuffer)
        
        // Keep digesting until the buffer is filled
        while destinationBuffer.count < totalLength {
            let combined = digestBuffer + dataAndSalt
            digestBuffer = insecureHash(input: combined)
            destinationBuffer.append(digestBuffer)
        }
        
        // Generate key and iv
        return (destinationBuffer[0..<32], destinationBuffer[32..<48])
    }
    
    private static func insecureHash(input: Data) -> Data {
        if #available(iOS 13.0, *) {
            // Use CryptoKit.Insecure.MD5 for hashing
            var insecureHasher = Insecure.MD5()
            insecureHasher.update(data: input)
            return Data(insecureHasher.finalize())
        } else {
            var digestBuffer = Data(count: Int(CC_MD5_DIGEST_LENGTH))
            _ = digestBuffer.withUnsafeMutableBytes {
                destinationPointer in input.withUnsafeBytes {
                    (pointer: UnsafeRawBufferPointer) in CC_MD5(
                        pointer.baseAddress!,
                        CC_LONG(input.count),
                        destinationPointer.bindMemory(to: UInt8.self).baseAddress!
                    )
                }
            }
            return digestBuffer
        }
    }
    
    private static func decrypt(_ saultedData: Data, withKey encryptionKey: Data) throws -> Data {
        // Check if the data has the prefix
        let saltIdentifier = "Salted__"
        guard String(data: saultedData[0..<8], encoding: .utf8) == saltIdentifier else {
            throw NineAnimatorError.providerError("Invalid resource data")
        }
        
        // 8 bytes of salt
        let salt = saultedData[8..<16]
        let data = saultedData[16...]
        
        // Calculate the key and iv
        let (key, iv) = self.generateKeyAndIV(encryptionKey, salt: salt)
        
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
                            keyPointer.baseAddress!,
                            kCCKeySizeAES256,
                            ivPointer.baseAddress!,
                            dataPointer.baseAddress!,
                            data.count,
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
            throw NineAnimatorError.providerError("Faild to decrypt resources")
        }
        
        return destinationBuffer[0..<decryptedBytes]
    }
}
