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

import Foundation

extension Simkl {
    struct SimklIdentifierEntry: Codable {
        var simkl_id: Int
    }
    
    struct SimklMediaEntry: Codable {
        var title: String
        var ids: SimklIdentifierEntry
        var poster: String?
    }
    
    struct SimklEpisodeEntry: Codable {
        var ids: SimklIdentifierEntry
        var watched_at: String?
        
        var lastWatchedDate: Date? {
            get {
                if let w = watched_at { return Simkl.dateFormatter.date(from: w) }
                return nil
            }
            set {
                if let d = newValue { watched_at = Simkl.dateFormatter.string(from: d) }
            }
        }
    }
    
    private static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }
    
    func reference(from link: AnimeLink) -> NineAnimatorPromise<ListingAnimeReference> {
        return apiRequest(
            "/search/anime",
            query: [
                "q": link.title,
                "page": 1,
                "limit": 1,
                "extended": "full",
                "client_id": clientId
            ],
            expectedResponseType: [[String: Any]].self
        ) .then {
            try $0.first.unwrap {
                try DictionaryDecoder().decode(SimklMediaEntry.self, from: $0)
            }
        } .then {
            entry in ListingAnimeReference(
                parentService: self,
                uniqueIdentifier: String(entry.ids.simkl_id),
                name: entry.title,
                artwork: try self.artworkUrl(fromPosterPath: entry.poster),
                userInfo: [:],
                state: nil
            )
        }
    }
    
    func episodeObjects(forReference reference: ListingAnimeReference) { }
}
