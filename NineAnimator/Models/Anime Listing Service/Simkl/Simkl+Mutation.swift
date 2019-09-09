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
    struct SimklStdMediaEpisodeEntry: Codable {
        var ids: SimklStdMediaIdentifierEntry
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
    
    static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }
    
    func update(_ reference: ListingAnimeReference, newState: ListingAnimeTrackingState) {
        do {
            let updateTask = apiRequest(
                "/sync/add-to-list",
                body: try JSONSerialization.data(
                    withJSONObject: [
                        "shows": [
                            [
                                "title": reference.name,
                                "to": self.stateToSimkl(newState),
                                "ids": [ "simkl": reference.uniqueIdentifier ]
                            ]
                        ]
                    ],
                    options: []
                ),
                method: .post,
                expectedResponseType: [String: Any].self
            ) .error {
                error in Log.error(
                    "[Simkl.com] Unable to update state for reference %@ because a communication problem: %@",
                    reference.name,
                    error
                )
            } .finally {
                _ in Log.info("[Simkl.com] Mutation request completed")
            }
            mutationQueues.append(updateTask)
        } catch {
            Log.error("[Simkl.com] Unable to update state for reference %@: %@", reference.name, error)
        }
    }
    
    func update(_ reference: ListingAnimeReference, didComplete episode: EpisodeLink, episodeNumber: Int?) {
        let task = episodeObjects(forReference: reference).thenPromise {
            episodes -> NineAnimatorPromise<Any> in
            guard let episodeNumber = {
                () -> Int? in
                var v: Int?
                
                if let numberPortion = episode.name.split(separator: "-")
                    .first?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    v = Int(numberPortion)
                }
                
                if let n = episodeNumber {
                    v = v ?? Int(n)
                }
                
                return v
            }() else { throw NineAnimatorError.responseError("Unable to infer") }
            
            guard let match = episodes.first(where: { $0.episode == episodeNumber }) else {
                throw NineAnimatorError.responseError("Unable to find a matching episode")
            }
            
            let stdUpdateObj = match.toStandardEpisodeObject()
            let updatingEpisodeDictionary: NSDictionary = try DictionaryEncoder().encode(stdUpdateObj)
            
            return self.apiRequest(
                "/sync/history",
                body: try JSONSerialization.data(
                    withJSONObject: [
                        "episodes": [ updatingEpisodeDictionary ]
                    ],
                    options: []
                ),
                expectedResponseType: Any.self
            )
        } .error { Log.error("[Simkl.com] Unable to push update: %@", $0) }
          .finally { _ in Log.info("[Simkl.com] Mutation request made") }
        mutationQueues.append(task)
    }
}
