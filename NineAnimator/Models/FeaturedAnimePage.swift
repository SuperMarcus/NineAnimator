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

struct FeaturedAnimePage {
    static let featuredAnimesRegex = try! NSRegularExpression(pattern: "<div class=\"item swiper-slide\" style=\"background-image: url\\(([^)]+)\\)[^h]+href=\"([^\"]+)\">([^<]+)", options: .caseInsensitive)
    
    static let latestUpdateAnimesRegex = try! NSRegularExpression(pattern: "(https:\\/\\/www1.9anime.to\\/watch[^\"]+)\"[^>]+>\\s+\\<img src=\"(https[^\"]+)\" alt=\"([^\"]+)[^>]+>", options: .caseInsensitive)
    
    let featured: [AnimeLink]
    
    let latest: [AnimeLink]
    
    init?(_ pageSource: String) throws{
        let featuredAnimesMatches = FeaturedAnimePage.featuredAnimesRegex.matches(in: pageSource, options: [], range: pageSource.matchingRange)
        self.featured = try featuredAnimesMatches.map {
            guard let imageLink = URL(string: pageSource[$0.range(at: 1)]) else { throw NineAnimatorError.responseError("parser error") }
            guard let animeLink = URL(string: pageSource[$0.range(at: 2)]) else { throw NineAnimatorError.responseError("parser error") }
            let title = pageSource[$0.range(at: 3)]
            return AnimeLink(title: title, link: animeLink, image: imageLink)
        }
        
        let latestAnimesMatches = FeaturedAnimePage.latestUpdateAnimesRegex.matches(in: pageSource, options: [], range: pageSource.matchingRange)
        self.latest = try latestAnimesMatches.map{
            guard let imageLink = URL(string: pageSource[$0.range(at: 2)]) else { throw NineAnimatorError.responseError("parser error") }
            guard let animeLink = URL(string: pageSource[$0.range(at: 1)]) else { throw NineAnimatorError.responseError("parser error") }
            let title = pageSource[$0.range(at: 3)]
            return AnimeLink(title: title, link: animeLink, image: imageLink)
        }
    }
}

extension NineAnimator {
    func loadHomePage(completionHandler: @escaping NineAnimatorCallback<FeaturedAnimePage>){
        let _ = request(.home) {
            (content, error) in
            if let error = error {
                self.removeCache(at: .home)
                completionHandler(nil, error)
                return
            }
            
            do{
                let page = try FeaturedAnimePage(content!)
                completionHandler(page, nil)
            } catch let e {
                self.removeCache(at: .home)
                completionHandler(nil, e)
            }
        }
    }
}
