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

/// Representing the name of the anime
struct ListingAnimeName: CustomStringConvertible {
    /// The default or user preferred name of the anime
    let `default`: String
    
    /// The english title of the anime
    ///
    /// An empty string if it does not exists
    let english: String
    
    /// The romaji title of the anime
    ///
    /// An empty string if it does not exists
    let romaji: String
    
    /// The native title of the anime
    ///
    /// An empty string if it does not exists
    let native: String
}

/// Representing a '2D' character in the anime
struct ListingAnimeCharacter {
    /// Name of the character in the anime
    let name: String
    
    /// Role of the character in the anime
    let role: String
    
    /// The name of the voice actor for the character
    let voiceActorName: String
    
    /// An image of the anime character
    let image: URL
}

/// Representing the ratings of an anime
struct ListingAnimeStatistics {
    /// A discrete distribution (frequency chart) of user ratings
    ///
    /// The average rating is calculated from this distribution
    let ratingsDistribution: [Double: Double]
    
    /// The number of ratings received
    let numberOfRatings: Int
    
    /// The total number of episodes
    let episodesCount: Int?
}

/// Representing the ratings
struct ListingAnimeReview {
    /// The author of the review
    let author: String
    
    /// The content of the review
    let content: String
}

/// Representing an airing episode
struct ListingAiringEpisode {
    /// Scheduled date of airing
    var scheduled: Date
    
    /// Episode number
    var episodeNumber: Int
}

/// Representing the detailed information of an listed anime
protocol ListingAnimeInformation {
    // Immedietly available information
    
    /// The listing reference of this `ListingAnimeInformation`
    ///
    /// The reference is used to identify the `ListingAnimeInformation`.
    /// Think of this struct as an equivalent of `Anime`
    var reference: ListingAnimeReference { get }
    
    /// The set of titles of this anime
    var name: ListingAnimeName { get }
    
    /// The URL pointing to the artwork image of this anime
    var artwork: URL { get }
    
    /// A list of URLs to the wallpapers
    var wallpapers: [URL] { get }
    
    /// The user-browsable page on the listing website
    var siteUrl: URL { get }
    
    /// A short description/synopsis of the anime
    var description: String { get }
    
    /// A list of information that is displayed in the information section
    var information: [String: String] { get }
    
    // Promisified and need-based information
    
    /// Retrieve the list of characters (2D) in the anime
    var characters: NineAnimatorPromise<[ListingAnimeCharacter]> { get }
    
    /// Retrieve the statistics and ratings of this anime
    var statistics: NineAnimatorPromise<ListingAnimeStatistics> { get }
    
    /// Retrieve the list of reviews authored on this website
    var reviews: NineAnimatorPromise<[ListingAnimeReview]> { get }
    
    /// Retrieve the list of related anime
    var relatedReferences: NineAnimatorPromise<[ListingAnimeReference]> { get }
    
    /// Retrieve the airing schedules for future episodes
    /// - Returns: A promise that resolves into a list of `ListingAiringEpisode` or an error. If an error or an empty list is received, the future airing schedules section will not be presented.
    var futureAiringSchedules: NineAnimatorPromise<[ListingAiringEpisode]> { get }
}
