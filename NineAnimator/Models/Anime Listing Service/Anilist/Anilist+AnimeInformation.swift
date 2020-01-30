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
import SwiftSoup

extension Anilist {
    class AnilistListingAnimeInformation: ListingAnimeInformation {
        var reference: ListingAnimeReference
        var name: ListingAnimeName
        var artwork: URL
        var wallpapers: [URL]
        var siteUrl: URL
        var description: String
        var information: [String: String]
        
        var characters: NineAnimatorPromise<[ListingAnimeCharacter]> {
            .firstly { [_characters] in _characters }
        }
        var statistics: NineAnimatorPromise<ListingAnimeStatistics> {
            .firstly {
                [_statistics] in
                guard _statistics.ratingsDistribution.count > 1 else {
                    throw NineAnimatorError.responseError("No rating distribution found.")
                }
                return _statistics
            }
        }
        var relatedReferences: NineAnimatorPromise<[ListingAnimeReference]> {
            .firstly { [_relations] in _relations }
        }
        var reviews: NineAnimatorPromise<[ListingAnimeReview]> { .fail(.unknownError) }
        
        // For now, all optional properties are fetched with other values
        var _characters: [ListingAnimeCharacter]
        var _statistics: ListingAnimeStatistics
        var _relations: [ListingAnimeReference]
        
        // swiftlint:disable cyclomatic_complexity
        init(_ reference: ListingAnimeReference, mediaEntry: NSDictionary) throws {
            func fuzzyDate(_ input: Any?) -> Date? {
                let inputFormatter = DateFormatter()
                inputFormatter.dateFormat = "yyyy/MM/dd"
                
                // Parse FuzzyDate
                if let input = input as? NSDictionary,
                    let day = input["day"] as? Int,
                    let month = input["month"] as? Int,
                    let year = input["year"] as? Int {
                    return inputFormatter.date(from: "\(year)/\(month)/\(day)")
                }
                return nil
            }
            
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .none
            
            self.reference = reference
            self.name = .init(
                default: try mediaEntry.value(at: "title.userPreferred", type: String.self),
                english: mediaEntry.value(forKeyPath: "title.english") as? String ?? "",
                romaji: mediaEntry.value(forKeyPath: "title.romaji") as? String ?? "",
                native: mediaEntry.value(forKeyPath: "title.native") as? String ?? ""
            )
            self.artwork = try some(
                URL(string: try mediaEntry.value(at: "coverImage.extraLarge", type: String.self)),
                or: .urlError
            )
            self.siteUrl = try some(
                URL(string: try mediaEntry.value(at: "siteUrl", type: String.self)),
                or: .urlError
            )
            self.description = try SwiftSoup
                .parse(try mediaEntry.value(at: "description", type: String.self))
                .text()
            
            self.wallpapers = []
            if let bannerImageString = mediaEntry.valueIfPresent(at: "bannerImage", type: String.self),
                let url = URL(string: bannerImageString) {
                self.wallpapers.append(url)
            }
            
            // Characters
            _characters = try mediaEntry
                .value(at: "characters.edges", type: [NSDictionary].self)
                .map { try ListingAnimeCharacter(characterEdgeEntry: $0) }
            
            // Related anime
            _relations = try mediaEntry
                .value(at: "relations.nodes", type: [NSDictionary].self)
                .compactMap { try? ListingAnimeReference(reference.parentService as! Anilist, withMediaEntry: $0) }
            
            // Statistics
            _statistics = try ListingAnimeStatistics(mediaEntry: mediaEntry)
            
            // Extra information
            var information = [String: String]()
            
            if let format = mediaEntry["format"] as? String {
                information["Format"] = format
            }
            
            if let status = mediaEntry["status"] as? String {
                switch status {
                case "FINISHED": information["Airing Status"] = "Finished"
                case "RELEASING": information["Airing Status"] = "Ongoing"
                case "NOT_YET_RELEASED": information["Airing Status"] = "Not Yet Released"
                case "CANCELLED": information["Airing Status"] = "Cancelled"
                default: break
                }
            }
            
            if let startDate = fuzzyDate(mediaEntry["startDate"]) {
                information["Start Date"] = formatter.string(from: startDate)
            }
            
            if let endDate = fuzzyDate(mediaEntry["endDate"]) {
                information["End Date"] = formatter.string(from: endDate)
            }
            
            if let session = mediaEntry["session"] as? String {
                switch session {
                case "WINTER": information["Session"] = "Winter"
                case "SPRING": information["Session"] = "Spring"
                case "SUMMER": information["Session"] = "Summer"
                case "FALL": information["Session"] = "Fall"
                default: break
                }
            }
            
            if let episodes = mediaEntry["episodes"] as? Int {
                information["Total Episodes"] = "\(episodes)"
            }
            
            if let duration = mediaEntry["duration"] as? Int {
                information["Episode Duration"] = "\(duration) Minutes"
            }
            
            if let countryOfOrigin = mediaEntry["countryOfOrigin"] as? String {
                information["Origin Country"] = countryOfOrigin
            }
            
            if let source = mediaEntry["source"] as? String {
                information["Source"] = [
                    "ORIGINAL": "Original",
                    "MANGA": "Manga",
                    "LIGHT_NOVEL": "Light Novel",
                    "VISUAL_NOVEL": "Visual Novel",
                    "VIDEO_GAME": "Video Game",
                    "OTHER": "Other"
                ][source]
            }
            
            if let updatedAt = mediaEntry["updatedAt"] as? Int {
                information["Last Update"] = formatter.string(
                    from: Date(timeIntervalSince1970: TimeInterval(updatedAt))
                )
            }
            
            self.information = information
        }
        // swiftlint:enable cyclomatic_complexity
    }
    
    func listingAnime(from reference: ListingAnimeReference) -> NineAnimatorPromise<ListingAnimeInformation> {
        graphQL(fileQuery: "AniListListingAnimeInformation", variables: [
            "mediaId": reference.uniqueIdentifier
        ]) .then {
            responseDictionary in
            guard let mediaEntry = responseDictionary["Media"] as? NSDictionary else {
                throw NineAnimatorError.responseError("Cannot find the media entry in the response")
            }
            return try AnilistListingAnimeInformation(reference, mediaEntry: mediaEntry)
        }
    }
}

private extension ListingAnimeCharacter {
    init(characterEdgeEntry: NSDictionary) throws {
        func assembleName(_ nameEntry: NSDictionary) -> String {
            var assemblingName = [String]()
            
            if let firstName = nameEntry["first"] as? String {
                assemblingName.append(firstName)
            }
            
            if let lastName = nameEntry["last"] as? String {
                assemblingName.append(lastName)
            }
            
            let name = assemblingName.joined(separator: " ")
            if let nativeName = (nameEntry["native"] as? String)?.trimmingCharacters(in: .whitespaces),
                !nativeName.isEmpty {
                return "\(name) (\(nativeName))"
            } else { return name }
        }
        
        // Name of the character
        self.name = assembleName(try characterEdgeEntry.value(at: "node.name", type: NSDictionary.self))
        
        // Role of the character
        self.role = try [
            "MAIN": "Main",
            "SUPPORTING": "Supporting",
            "BACKGROUND": "Background"
        ][try characterEdgeEntry.value(at: "role", type: String.self)] ??
            (try characterEdgeEntry.value(at: "role", type: String.self))
        
        // Parse voice actor
        if let voiceActorEntry = (characterEdgeEntry["voiceActors"] as? [NSDictionary])?.first,
            let voiceActorName = voiceActorEntry["name"] as? NSDictionary {
            self.voiceActorName = assembleName(voiceActorName)
        } else { self.voiceActorName = "" }
        
        // Character avatar
        self.image = try some(
            URL(string: try characterEdgeEntry.value(at: "node.image.large", type: String.self)),
            or: .urlError
        )
    }
}

private extension ListingAnimeStatistics {
    init(mediaEntry: NSDictionary) throws {
        // Ratings distribution
        ratingsDistribution = Dictionary(
            uniqueKeysWithValues: try mediaEntry
                .value(at: "stats.scoreDistribution", type: [NSDictionary].self)
                .map {
                    (
                        Double(try $0.value(at: "score", type: Int.self)),
                        Double(try $0.value(at: "amount", type: Int.self))
                    )
                }
        )
        
        // Calculate total amount of ratings from the sum of all
        numberOfRatings = ratingsDistribution.reduce(0) {
            $0 + Int($1.value)
        }
        
        // Number of episodes
        episodesCount = mediaEntry["episodes"] as? Int
    }
}
