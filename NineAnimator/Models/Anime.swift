//
//  Anime.swift
//  NineAnimator
//
//  Created by Xule Zhou on 12/5/18.
//  Copyright © 2018 Marcus Zhou. All rights reserved.
//

import Foundation
import Alamofire
import SwiftSoup

extension NineAnimator {
    func anime(with link: AnimeLink, onCompletion handler: @escaping NineAnimatorCallback<Anime>) {
        session.request(link).responseString{
            response in
            if case let .failure(error) = response.result {
                debugPrint("Error: Failiure on request: \(error)")
                handler(nil, error)
                return
            }
            
            guard let pageString = response.value else {
                debugPrint("Error: No content received")
                handler(nil, NineAnimatorError.responseError("no content received from server"))
                return
            }
            
            Anime.parse(link, page: pageString, with: self.ajaxSession, onCompletion: handler)
        }
    }
}

struct Anime {
    let link: AnimeLink
    
    struct AjaxPath: URLConvertible {
        static let ping = AjaxPath("/ajax/film/servers-ping")
        
        static func servers(for identifier: String) -> AjaxPath {
            return AjaxPath("/ajax/film/servers/\(identifier)")
        }
        
        static func episode(for videoIdentifier: String, on serverIdentifier: String) -> AjaxPath {
            return AjaxPath("/ajax/episode/info?id=\(videoIdentifier)&server=\(serverIdentifier)")
        }
        
        let value: String
        init(_ v: String) { value = v }
        
        func asURL() -> URL { return URL(string: NineAnimator.default.endpoint + value)! }
    }
    
    static let animeAliasRegex = try! NSRegularExpression(pattern: "<p class=\"alias\">([^<]+)", options: .caseInsensitive)
    static let animeAttributesRegex = try! NSRegularExpression(pattern: "<dt>([^<:]+):*<\\/dt>\\s+<dd>([^<]+)")
    static let animeResourceTagsRegex = try! NSRegularExpression(pattern: "<div id=\"servers-container\" data-id=\"([^\"]+)\" data-bind-api=\"#player\" data-epid=\"([^\"]*)\" data-epname=\"[^\"]*\"\\s*>", options: .caseInsensitive)
    static let animeServerListRegex = try! NSRegularExpression(pattern: "<span\\s+class=[^d]+data-name=\"([^\"]+)\">([^<]+)", options: .caseInsensitive)
    
    fileprivate static func parse(_ link: AnimeLink, page: String, with session: Alamofire.SessionManager, onCompletion handler: @escaping NineAnimatorCallback<Anime>){
        
        let alias: String? = {
            let matches = Anime.animeAliasRegex.matches(in: page, options: [], range: page.matchingRange)
            return matches.count > 0 ? page[matches[0].range(at: 1)] : nil
        }()
        
        let animeAttributes: [(name: String, value: String)] = {
            let matches = Anime.animeAttributesRegex.matches(in: page, options: [], range: page.matchingRange)
            return matches.filter { page[$0.range(at: 2)].isEmpty }
                          .map { (page[$0.range(at: 1)], page[$0.range(at: 2)]) }
        }()
        
        let animeResourceTags: (id: String, episode: String) = {
            let matches = Anime.animeResourceTagsRegex.matches(in: page, options: [], range: page.matchingRange)
            return (page[matches[0].range(at: 1)], page[matches[0].range(at: 2)])
        }()
        
        var animeServers = [(name: String, server: String)]()
        var animeEpisodes = [String:[(name: String, episodeIdentifier: String)]]()
        
        let ajaxHeaders: Alamofire.HTTPHeaders = [ "Referer": link.link.absoluteString ]
        
        let onRetriveServers: ((Alamofire.DataResponse<Any>) -> ()) = {
            response in
            if case let .failure(error) = response.result {
                debugPrint("Error: Failiure on request: \(error)")
                handler(nil, error)
                return
            }
            
            guard let responseJson = response.value as? NSDictionary else {
                debugPrint("Error: No content received")
                handler(nil, NineAnimatorError.responseError("no content received from server"))
                return
            }
            
            guard let htmlList = responseJson["html"] as? String else {
                debugPrint("Error: Invalid response")
                handler(nil, NineAnimatorError.responseError("unable to retrive episode list from responses"))
                return
            }
            
            let matches = Anime.animeServerListRegex.matches(in: htmlList, options: [], range: htmlList.matchingRange)
            
            for match in matches {
                animeServers.append((
                    name: htmlList[match.range(at: 2)],
                    server: htmlList[match.range(at: 1)]
                ))
            }
            
            debugPrint("Info: \(animeServers.count) servers found for this anime.")
            
            do{
                let soup = try SwiftSoup.parse(htmlList)
                
                for server in try soup.select("div.server") {
                    let serverIdentifier = try server.attr("data-id")
                    animeEpisodes[serverIdentifier] = try server.select("li>a")
                        .map { (name: try $0.text(), episodeIdentifier: try $0.attr("data-id")) }
                    debugPrint("Info: \(animeEpisodes[serverIdentifier]!.count) episodes found on server \(serverIdentifier)")
                }
            }catch{
                debugPrint("Unable to parse servers and episodes")
                handler(nil, error)
            }
        }
        
        //Ping the server
        session.request(AjaxPath.ping, headers: ajaxHeaders).responseJSON {
            response in
            if case let .failure(error) = response.result {
                debugPrint("Error: Failiure on request: \(error)")
                handler(nil, error)
                return
            }
            
            guard let responseJson = response.value as? NSDictionary else {
                debugPrint("Error: No content received")
                handler(nil, NineAnimatorError.responseError("no content received from server"))
                return
            }
            
            guard (responseJson["valid"] as? Bool) == true else {
                debugPrint("Error: Server characterized this session as invalid")
                handler(nil, NineAnimatorError.responseError("invalid session"))
                return
            }
            
            debugPrint("Info: Session is valid")
            debugPrint("- Alias: \(alias ?? "None")")
            debugPrint("- Attributes: \(animeAttributes)")
            debugPrint("- Resource Identifiers: ID=\(animeResourceTags.id), EPISODE=\(animeResourceTags.episode)")
            
            //Request server and episode lists
            session.request(AjaxPath.servers(for: animeResourceTags.id)).responseJSON(completionHandler: onRetriveServers)
        }
    }
}
