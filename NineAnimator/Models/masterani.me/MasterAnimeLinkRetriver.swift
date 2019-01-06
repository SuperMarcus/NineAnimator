//
//  This file is part of the NineAnimator project.
//
//  Copyright © 2018 Marcus Zhou. All rights reserved.
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

extension NASourceMasterAnime {
    static let animeUrlSlugRegex = try! NSRegularExpression(pattern: "\\/anime\\/(?:(?:info)|(?:watch))\\/([^\\/]+)", options: [.caseInsensitive])
    static let animeUrlEpisodeNumberRegex = try! NSRegularExpression(pattern: "\\/anime\\/watch\\/[^\\/]+\\/(\\d+)", options: [.caseInsensitive])
    
    func link(from url: URL, _ handler: @escaping NineAnimatorCallback<AnyLink>) -> NineAnimatorAsyncTask? {
        let urlString = url.absoluteString
        
        guard let match = NASourceMasterAnime.animeUrlSlugRegex.matches(in: urlString, options: [], range: urlString.matchingRange).first else {
            handler(nil, NineAnimatorError.urlError)
            return nil
        }
        
        let slug = urlString[match.range(at: 1)]
        let reconstructedAnimeUrl = URL(string: "\(endpoint)/anime/info/\(slug)")!
        
        return anime(from: reconstructedAnimeUrl) {
            [urlString, handler] anime, responseError in
            guard let anime = anime else { return handler(nil, responseError) }
            
            if let match = NASourceMasterAnime.animeUrlEpisodeNumberRegex.matches(in: urlString, options: [], range: urlString.matchingRange).first,
                let episodeNumber = Int(urlString[match.range(at: 1)]) {
                let episodeLinks = anime.episodes
                    .flatMap { $0.value }
                    .filter {
                        let currentEpisodeNumber = $0.identifier.split(separator: ":")[1]
                        return currentEpisodeNumber == "\(episodeNumber)"
                    }
                
                if episodeLinks.isEmpty {
                    return handler(nil, NineAnimatorError.responseError("No episode found for this link"))
                }
                
                if let recentServer = NineAnimator.default.user.recentServer,
                    let episodeLink = episodeLinks.first(where: { $0.server == recentServer }) {
                    return handler(.episode(episodeLink), nil)
                }
                
                handler(.episode(episodeLinks.first!), nil)
            }
            
            handler(.anime(anime.link), nil)
        }
    }
}
