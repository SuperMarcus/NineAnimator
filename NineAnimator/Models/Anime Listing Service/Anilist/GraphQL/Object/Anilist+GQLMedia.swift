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

// swiftlint:disable discouraged_optional_boolean
extension Anilist {
    struct GQLMedia: Codable {
        var id: Int?
        var idMal: Int?
        var title: GQLMediaTitle?
        var type: GQLMediaType?
        var status: GQLMediaStatus?
        var description: String?
        var startDate: GQLFuzzyDate?
        var endDate: GQLFuzzyDate?
        var season: GQLMediaSeason?
        var episodes: Int?
        var duration: Int?
        var chapters: Int?
        var volumes: Int?
        var isLicensed: Bool?
        var source: GQLMediaSource?
        var hashtag: String?
        var trailer: GQLMediaTrailer?
        var updatedAt: Int?
        var coverImage: GQLMediaCoverImage?
        var bannerImage: String?
        var genres: [String]?
        var synonyms: [String]?
        var averageScore: Int?
        var meanScore: Int?
        var popularity: Int?
        var trending: Int?
//        var tags: [GQLMediaTag]?
        var isFavourite: Bool?
        var isAdult: Bool?
        var mediaListEntry: GQLMediaList?
        
        // There are many limitations of using structs in swift as decoding mediums.
//        var nextAiringEpisode: GQLAiringSchedule?
        
        var siteUrl: String?
        var autoCreateForumThread: Bool?
        var modNotes: String?
    }
    
    struct GQLMediaTitle: Codable {
        var romaji: String?
        var english: String?
        var native: String?
        var userPreferred: String?
    }
    
    enum GQLMediaType: String, Codable {
        case anime = "ANIME"
        case manga = "MANGA"
    }
    
    enum GQLMediaStatus: String, Codable {
        case finished = "FINISHED"
        case releasing = "RELEASING"
        case notYetReleased = "NOT_YET_RELEASED"
        case cancelled = "CANCELLED"
    }
    
    enum GQLMediaSeason: String, Codable {
        case winter = "WINTER"
        case spring = "SPRING"
        case summer = "SUMMER"
        case fall = "FALL"
    }
    
    enum GQLMediaSource: String, Codable {
        case original = "ORIGINAL"
        case manga = "MANGA"
        case lightNovel = "LIGHT_NOVEL"
        case visualNovel = "VISUAL_NOVEL"
        case videoGame = "VIDEO_GAME"
        case other = "OTHER"
    }
    
    struct GQLMediaTrailer: Codable {
        var id: String?
        var site: String?
    }
    
    struct GQLMediaCoverImage: Codable {
        var extraLarge: String?
        var large: String?
        var medium: String?
    }
    
    struct GQLMediaList: Codable {
        var id: Int?
        var userId: Int?
        var mediaId: Int?
        var status: GQLMediaListStatus?
    }
    
    enum GQLMediaListStatus: String, Codable {
        case current = "CURRENT"
        case planning = "PLANNING"
        case completed = "COMPLETED"
        case dropped = "DROPPED"
        case paused = "PAUSED"
        case repeating = "REPEATING"
    }
}
