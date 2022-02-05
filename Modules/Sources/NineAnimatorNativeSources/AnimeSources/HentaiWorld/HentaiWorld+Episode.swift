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
import NineAnimatorCommon
import SwiftSoup

extension NASourceHentaiWorld {
    func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        self.requestManager.request(url: link.identifier, handling: .browsing)
            .responseData
                    .then {
                        responseContent in
                        let data = responseContent
                        let utf8Text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
                        let  bowl = try SwiftSoup.parse(utf8Text)
                        var video = try bowl.select("div.downloads div.widget-body a").attr("href").replacingOccurrences(of: "http://", with: "https://")
                        if video.contains("download-file.php?id=") {
                            video = video.replacingOccurrences(of: "download-file.php?id=", with: "")
                        }
                        return Episode(
                            link,
                            target: try URL(protocolRelativeString: video, relativeTo: self.endpointURL).tryUnwrap(),
                            parent: anime
                        )
                    }
            }
}
