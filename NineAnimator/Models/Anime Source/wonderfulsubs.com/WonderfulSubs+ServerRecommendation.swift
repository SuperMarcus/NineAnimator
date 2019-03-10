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

extension NASourceWonderfulSubs {
    func _recommendServer(for anime: Anime) -> Anime.ServerIdentifier? {
        let recommendationPiority: [Anime.ServerIdentifier: Double] = [
            "cr:subs": 1000,
            "ka:subs": 900,
            "fa:subs": 800,
            "cr:dubs": 700
        ]
        let serverWithPiority = anime.servers.map {
            server -> (Anime.ServerIdentifier, Double) in
            let identifier = server.key
            return (identifier, recommendationPiority[identifier.lowercased()] ?? 500)
        }
        return serverWithPiority.max { $0.1 < $1.1 }?.0
    }
}
