//
//  SearchPage.swift
//  NineAnimator
//
//  Created by Xule Zhou on 12/8/18.
//  Copyright © 2018 Marcus Zhou. All rights reserved.
//

import Foundation
import SwiftSoup

protocol SearchPageDelegate {
    //Index of the page (starting from zero)
    func pageIncoming(_: Int, in: SearchPage)
    
    func noResult(in: SearchPage)
}

class SearchPage {
    private(set) var query: String
    private(set) var totalPages: Int? = nil
    var delegate: SearchPageDelegate? = nil
    
    var moreAvailable: Bool {
        return totalPages == nil || (_results.count < totalPages!)
    }
    
    var availablePages: Int { return _results.count }
    
    private var _results: [[AnimeLink]]
    private var _animator: NineAnimator
    private var _lastRequest: NineAnimatorAsyncTask? = nil
    
    init(_ animator: NineAnimator, query: String) {
        self.query = query
        self._animator = animator
        self._results = []
        //Request the first page
        more()
    }
    
    deinit {
        if let request = _lastRequest { request.cancel() }
    }
    
    func animes(on page: Int) -> [AnimeLink] { return _results[page] }
    
    func more(){
        if moreAvailable && _lastRequest == nil {
            debugPrint("Info: Requesting page \(_results.count + 1) for query \(query)")
            let loadingIndex = _results.count
            _lastRequest = _animator.request(.search(keyword: query, page: loadingIndex + 1)){
                response, error in
                
                defer{ self._lastRequest = nil }
                
                if self._results.count > loadingIndex { return }
                
                guard let response = response else {
                    debugPrint("Error: \(error!)")
                    return
                }
                
                do{
                    let bowl = try SwiftSoup.parse(response)
                    
                    if let totalPagesString = try? bowl.select("span.total").text(),
                        let totalPages = Int(totalPagesString) { self.totalPages = totalPages  }
                    else { self.totalPages = 1 }
                    
                    let films = try bowl.select("div.film-list>div.item")
                    var animes = [AnimeLink]()
                    
                    for film in films {
                        let nameElement = try film.select("a.name")
                        let name = try nameElement.text()
                        let linkString = try nameElement.attr("href")
                        let coverImageString = try film.select("img").attr("src")
                        
                        guard let link = URL(string: linkString),
                            let coverImage = URL(string: coverImageString) else {
                                debugPrint("Warn: an invalid link was extracted from the search result page")
                                continue
                        }
                        
                        let anime = AnimeLink(title: name, link: link, image: coverImage)
                        animes.append(anime)
                    }
                    
                    if animes.count > 0 {
                        let newSection = self._results.count
                        self._results.append(animes)
                        self.delegate?.pageIncoming(newSection, in: self)
                    } else {
                        debugPrint("Info: No matches")
                        self.delegate?.noResult(in: self)
                    }
                }catch{
                    debugPrint("Error when loading more results: \(error)")
                }
            }
        }
    }
}

extension NineAnimator {
    func search(_ keyword: String) -> SearchPage {
        return SearchPage(self, query: keyword)
    }
}
