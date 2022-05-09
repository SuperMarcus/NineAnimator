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
import Foundation
import NineAnimatorCommon

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
    
    private static let apiBaseSourceURL = URL(string: "https://rapid-cloud.ru/ajax/embed-6/getSources")!
    private var webSocket: URLSessionWebSocketTask?
    private var semaphore = DispatchSemaphore(value: 0)
    private var sid: String = ""
    
    func parse(episode: Episode, with session: Session, forPurpose _: Purpose, onCompletion handler: @escaping NineAnimatorCallback<PlaybackMedia>) -> NineAnimatorAsyncTask {
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
            responseContent in
            
            let recaptchaSiteKey = try (self.recaptchaSiteKeyRegex
                                        .firstMatch(in: responseContent)?
                                        .firstMatchingGroup)
                .tryUnwrap(.providerError("Could not find recaptchaNumber"))
            let recaptchaNumber = try (self.recaptchaNumberRegex
                                        .firstMatch(in: responseContent)?
                                        .firstMatchingGroup)
                .tryUnwrap(.providerError("Could not find recaptchaNumber"))
            
            return self.getTokenRecaptcha(with: session, recaptchaSiteKey: recaptchaSiteKey, url: episode.target)
                .thenPromise {
                    token -> NineAnimatorPromise<PlaybackMedia> in
                    
                    let episodeComponents = episode.target.pathComponents
                    
                    guard episodeComponents.count == 3 else {
                        throw NineAnimatorError.urlError
                    }
                    
                    let resourceIdentifer = episodeComponents[2]
                    let sid = self.wss()
                                        
                    return NineAnimatorPromise {
                        callback in session.request(
                            RapidCloudParser.apiBaseSourceURL,
                            parameters: [
                                "id": resourceIdentifer,
                                "_token": token,
                                "_number": recaptchaNumber,
                                "sId": sid
                            ],
                            headers: [
                                "referer": episode.target.absoluteString,
                                "x-requested-with": "XMLHttpRequest",
                                "user-agent": self.defaultUserAgent,
                                "accept": "*/*",
                                "accept-language": "en-US,en;q=0.5",
                                "Connection": "keep-alive"
                            ]
                        ) .responseData {
                            callback($0.value, $0.error)
                        }
                    } .then {
                        try JSONDecoder().decode(SourcesAPIResponse.self, from: $0)
                    } .then {
                        decoded -> PlaybackMedia in
                        
                        let selectedSource = try decoded
                            .sources
                            .first
                            .tryUnwrap(.providerError("No available source was found"))
                        let resourceUrl = try URL(string: selectedSource.file).tryUnwrap(.urlError)
                        
                        Log.info("(RapidCloud Parser) found asset at %@", resourceUrl.absoluteString)
                        
                        let subtitles = try decoded.tracks.compactMap {
                            track -> (url: URL, name: String, language: String)? in
                            if track.kind == "captions" {
                                return  (
                                    url: try URL(string: track.file!).tryUnwrap(),
                                    name: track.kind,
                                    language: try track.label.tryUnwrap()
                                )
                            }
                            return nil
                        }
                                                                               
                        if subtitles.isEmpty {
                            return BasicPlaybackMedia(
                                url: resourceUrl,
                                parent: episode,
                                contentType: "application/vnd.apple.mpegurl",
                                headers: [
                                    "origin": "https://rapid-cloud.ru/",
                                    "referer": "https://rapid-cloud.ru/",
                                    "user-agent": self.defaultUserAgent,
                                    "SID": sid
                                ],
                                isAggregated: true
                            )
                        } else {
                            return CompositionalPlaybackMedia(
                                url: resourceUrl,
                                parent: episode,
                                contentType: "application/vnd.apple.mpegurl",
                                headers: [
                                    "origin": "https://rapid-cloud.ru/",
                                    "referer": "https://rapid-cloud.ru/",
                                    "user-agent": self.defaultUserAgent,
                                    "SID": sid
                                ],
                                subtitles: subtitles
                            )
                        }
                    }
                }
        } .handle(handler)
    }
    
    func isParserRecommended(forPurpose purpose: Purpose) -> Bool {
        // Subtitle not support for offline playback
        return purpose != .download
    }
}

// MARK: - Request Helpers
private extension RapidCloudParser {
    private static let WS_SOCKET_URL = "wss://ws1.rapid-cloud.ru/socket.io/?EIO=4&transport=websocket"
    private static let RECAPTCHA_API_JS = "https://www.google.com/recaptcha/api.js"

    private static let vTokenRegex = try! NSRegularExpression(
        pattern: #"releases/([^/&?#]+)"#,
        options: .caseInsensitive
    )
    private static let recaptchaTokenRegex =  try! NSRegularExpression(
        pattern: #"recaptcha-token.+?=\"(.+?)\""#,
        options: .caseInsensitive
    )
    private static let tokenRegex =  try! NSRegularExpression(
        pattern: #"rresp\",\"(.+?)\""#,
        options: .caseInsensitive
    )
    
    private static let sidRegex =  try! NSRegularExpression(
        pattern: #"\"sid\":\"(.+?)\""#,
        options: .caseInsensitive
    )
    
    @objc private func onPlaybackDidEnd(_ notification: Notification) {
        DispatchQueue.global().async { [weak self] in self?.disconnect() }
    }
    
    private func wss() -> String {
        Log.info("(RapidCloud Parser) Websocket session started")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onPlaybackDidEnd(_:)),
            name: .playbackDidEnd,
            object: nil
        )
        
        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: URL(string: RapidCloudParser.WS_SOCKET_URL)!)
        webSocket?.resume()
                
        ping()
        receive()
        send(text: "40")
        _ = semaphore.wait(timeout: .now() + 5)
        
        return sid
    }
    
    private func receive() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                Log.error("(RapidCloud Parser) Websocket receive error %@", error)
            case .success(let message):
                switch message {
                case .data(let data): Log.info("(RapidCloud Parser) Websocket receive data %@", data)
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
    
    private func send(text: String) {
        let message = URLSessionWebSocketTask.Message.string(text)
        webSocket?.send(message) { error in
            if let error = error {
                Log.error("(RapidCloud Parser) Websocket send error %@", error)
            }
        }
    }
    
    private func ping() {
        webSocket?.sendPing { error in
            if let error = error {
                Log.error("(RapidCloud Parser) Websocket ping error %@", error)
            } else {
                // Websocket connect still alive
                DispatchQueue.global().asyncAfter(deadline: .now() + 10) { [weak self] in
                    self?.ping()
                }
            }
        }
    }
    
    private func disconnect() {
        Log.info("(RapidCloud Parser) Websocket session ended")
        webSocket?.cancel(with: .goingAway, reason: "Connection ended".data(using: .utf8))
    }
    
    func getTokenRecaptcha(with session: Session, recaptchaSiteKey: String, url: URL) -> NineAnimatorPromise<String> {
        NineAnimatorPromise {
            callback in session.request(
                RapidCloudParser.RECAPTCHA_API_JS,
                parameters: [ "render": recaptchaSiteKey ],
                headers: [ "referer": url.absoluteString ]
            ).responseString {
                callback($0.value, $0.error)
            }
        } .thenPromise {
            recaptchaOut in
            
            let vToken = try (
                RapidCloudParser.vTokenRegex.firstMatch(in: recaptchaOut)?.firstMatchingGroup
            ).tryUnwrap()
            let domain = "https://\(url.host!):443".data(using: .utf8)?.base64EncodedString().replacingOccurrences(of: "=", with: "") ?? ""
            
            return NineAnimatorPromise {
                callback in session.request(
                    "https://www.google.com/recaptcha/api2/anchor",
                    parameters: [
                        "ar": 1,
                        "k": recaptchaSiteKey,
                        "co": domain,
                        "hi": "en",
                        "v": vToken,
                        "size": "invisible",
                        "cb": 123456789
                    ]
                ) .responseString {
                    callback($0.value, $0.error)
                }
            } .thenPromise {
                anchorOut in
                            
                let recaptchaToken = try (
                    RapidCloudParser.recaptchaTokenRegex.firstMatch(in: anchorOut)?.firstMatchingGroup
                ).tryUnwrap()
                
                return NineAnimatorPromise {
                    callback in session.request(
                        "https://www.google.com/recaptcha/api2/reload?k=\(recaptchaSiteKey)",
                        method: .post,
                        parameters: [
                            "v": vToken,
                            "reason": "q",
                            "k": recaptchaSiteKey,
                            "c": recaptchaToken,
                            "sa": "",
                            "co": domain
                        ],
                        headers: [ "referer": "https://www.google.com/recaptcha/api2" ]
                    ).responseString {
                        callback($0.value, $0.error)
                    }
                } .then {
                    tokenOut in
                    
                    let token = try (
                        RapidCloudParser.tokenRegex.firstMatch(in: tokenOut)?.firstMatchingGroup
                    ).tryUnwrap()
                    
                    return token
                }
            }
        }
    }
}

// MARK: - Request-Releated Structs
extension RapidCloudParser {
    private struct SourcesAPIResponse: Codable {
        let sources: [Source]
        let sourcesBackup: [String?]
        let tracks: [Track]
    }

    private struct Source: Codable {
        let file: String
        let type: String
    }
    
    private struct Track: Codable {
        let file: String?
        let kind: String
        let label: String?
    }
}
