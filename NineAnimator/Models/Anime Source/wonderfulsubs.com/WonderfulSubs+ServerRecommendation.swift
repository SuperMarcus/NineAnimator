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

extension NASourceWonderfulSubs {
    func _recommendServer(for anime: Anime) -> Anime.ServerIdentifier? {
        _recommendServer(for: anime, ofPurpose: .playback).first
    }
    
    func _recommendServer(for anime: Anime, ofPurpose purpose: VideoProviderParser.Purpose) -> [Anime.ServerIdentifier] {
        var knownPiorities = [Anime.ServerIdentifier: Double]()
        var fallbackPiority: Double = 500
        var cutoffPiority: Double = 0

        // More research is needed to figure out what works and what doesn't
        switch purpose {
        case .playback:
            knownPiorities = [
                "cr:subs": 1000,
                "ka:subs": 900,
                "fa:subs": 800,
                "cr:dubs": 700
            ]
            fallbackPiority = 500
            cutoffPiority = -1 // Do not cutoff
        case .download:
            knownPiorities = [
                "cr:subs": 1000,
                "ka:subs": 900,
                "fa:subs": 800,
                "cr:dubs": 700
            ]
            fallbackPiority = 100
            cutoffPiority = 0
        case .googleCast:
            knownPiorities = [
                "cr:subs": 1000,
                "ka:subs": 900,
                "fa:subs": 800,
                "cr:dubs": 700
            ]
            fallbackPiority = 100
            cutoffPiority = 0
        }
        
        return _recommendServers(
            for: anime,
            withPiorities: knownPiorities,
            fallbackPiority: fallbackPiority,
            cutoffPiority: cutoffPiority
        )
    }
    
    fileprivate func _recommendServers(for anime: Anime, withPiorities piorities: [Anime.ServerIdentifier: Double], fallbackPiority: Double, cutoffPiority: Double) -> [Anime.ServerIdentifier] {
        anime.servers.map {
            server -> (Anime.ServerIdentifier, Double) in
            let identifier = server.key
            return (identifier, piorities[identifier.lowercased()] ?? fallbackPiority)
        } .filter {
            $0.1 > cutoffPiority
        } .sorted {
            $0.1 > $1.1
        } .map { $0.0 }
    }
}
