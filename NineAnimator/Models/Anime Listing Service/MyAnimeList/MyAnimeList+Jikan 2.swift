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

extension MyAnimeList {
    /// Jikan REST v3 api endpoint
    private static let jikanEndpoint = URL(string: "https://api.jikan.moe/v3")!
    
    func jikanRequestAnimeStatistics(_ reference: ListingAnimeReference) -> NineAnimatorPromise<JikanAnimeStatistics> {
        jikanRequest([
            "anime",
            reference.uniqueIdentifier,
            "stats"
        ], responseType: JikanAnimeStatistics.self)
    }
    
    func jikanRequestCharactersAndStaffs(_ reference: ListingAnimeReference) -> NineAnimatorPromise<JikanAnimeCharactersStaffs> {
        jikanRequest([
            "anime",
            reference.uniqueIdentifier,
            "characters_staff"
        ], responseType: JikanAnimeCharactersStaffs.self)
    }
    
    func jikanRequestAnime(_ reference: ListingAnimeReference) -> NineAnimatorPromise<JikanAnime> {
        jikanRequest([
            "anime",
            reference.uniqueIdentifier
        ], responseType: JikanAnime.self)
    }
    
    private func jikanRequest<T: Decodable>(_ pathComponents: [String], responseType: T.Type) -> NineAnimatorPromise<T> {
        self.request(pathComponents.reduce(MyAnimeList.jikanEndpoint) {
            $0.appendingPathComponent($1)
        }) .then {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: $0)
        }
    }
}

// MARK: - Type Definitions
extension MyAnimeList {
    struct JikanAnimeCharactersStaffs: Codable {
        var requestHash: String
        var requestCached: Bool
        var requestCacheExpiry: Int
        var characters: [JikanCharacter]
    }
    
    struct JikanCharacter: Codable {
        var malId: Int
        var url: URL
        var imageUrl: URL
        var name: String
        var role: String
        var voiceActors: [JikanVoiceActor]
    }
    
    struct JikanVoiceActor: Codable {
        var malId: Int
        var name: String
        var url: URL
        var imageUrl: URL
        var language: String
    }
    
    struct JikanAnimeStatistics: Codable {
        var requestHash: String
        var requestCached: Bool
        var requestCacheExpiry: Int
        var watching: Int
        var completed: Int
        var onHold: Int
        var dropped: Int
        var planToWatch: Int
        var total: Int
        var scores: [String: JikanAnimeScoreDistributionFrequency]
    }
    
    struct JikanAnimeScoreDistributionFrequency: Codable {
        var votes: Int
        var percentage: Double
    }
    
    struct JikanAnime: Codable {
        var requestHash: String
        var requestCached: Bool
        var requestCacheExpiry: Int
        var malId: Int
        var url: URL
        var imageUrl: URL?
        var trailerUrl: URL?
        var title: String
        var titleEnglish: String?
        var titleJapanese: String?
        var titleSynonyms: [String]
        var type: String?
        var source: String?
        var episodes: Int?
        var status: String?
        var airing: Bool
        var aired: JikanAnimeAired?
        var duration: String?
        var rating: String? // PG rating
        var score: Double?
        var scored_by: Int?
        var rank: Int?
        var popularity: Int?
        var members: Int?
        var favorites: Int?
        var synopsis: String?
        var background: String?
        var premiered: String?
        var broadcast: String?
    }
    
    struct JikanAnimeAired: Codable {
        var from: Date
        var to: Date
        var string: String
    }
}
