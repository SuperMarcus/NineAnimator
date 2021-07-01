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

import Kingfisher
import NineAnimatorCommon
import NineAnimatorNativeListServices
import SwiftUI

@available(iOS 14.0, *)
struct ImageSearchResultsView: View {
    @Binding var searchResults: [TraceMoe.TraceMoeSearchResult]
    
    var body: some View {
        ScrollView {
            AdaptiveStack(horizontalAlignment: .leading, verticalAlignment: .top, verticalSpacing: 15) {
                TopResultView(result: searchResults[0])
                    // Assigning manual id to ensure smooth transitions when
                    // adaptive stack switches between HStack and VStack
                    .id("FIRST RESULT")
                if searchResults.count > 1 {
                    VStack(alignment: .leading) {
                        Text("Similar Results")
                            .font(.title2)
                            .fontWeight(.bold)
                        ForEach(searchResults[1...], id: \.video) { searchResult in
                            SimilarAnimeView(result: searchResult)
                        }
                    }
                    // Assigning manual id to ensure smooth transitions when
                    // adaptive stack switches between HStack and VStack
                    .id("SIMILAR RESULTS")
                }
            }
            .padding([.bottom, .horizontal])
        }
        .navigationTitle("Search Results")
        // Fixes SwiftUI Bug With Navigation bar and ScrollView Interactions
        // https://stackoverflow.com/a/64281045
        .padding(.top, 1)
    }
}

@available(iOS 14.0, *)
private extension ImageSearchResultsView {
    struct TopResultView: View {
        let result: TraceMoe.TraceMoeSearchResult
        @State private var imageRequestTask: NineAnimatorAsyncTask?
        @State private var imageURL: URL?
        @State private var animeSynopsis: String?
        
        var body: some View {
            VStack(alignment: .leading) {
                LoopingVideoPlayer(videoURL: result.video)
                    .cornerRadius(8)
                    .aspectRatio(16/9, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                Button { openAnilistView() } label: {
                    HStack(alignment: .top) {
                        if let coverURL = imageURL {
                            KFImage(coverURL)
                                .fade(duration: 0.5)
                                .resizable()
                                .frame(width: 100, height: 150)
                                .cornerRadius(8)
                        } else {
                            ProgressView()
                                .frame(width: 100, height: 150, alignment: .center)
                                .foregroundColor(.clear)
                        }
                        VStack(alignment: .leading) {
                            AnimeTitlesView(result: result)
                            AnimeDetailedInfoView(result: result, synopsis: $animeSynopsis)
                        }
                    }
                }
                // Prevent button from changing text colour to accent colour
                .foregroundColor(.primary)
            }
            .onLoad {
                retrieveAnilistInfo()
            }
        }
        
        func retrieveAnilistInfo() {
            let anilist = NineAnimator.default.service(type: Anilist.self)
            let listingReference = ListingAnimeReference(
                anilist,
                name: result.anilist.title.romaji ?? "Unknown Title",
                identifier: String(result.anilist.id)
            )
            imageRequestTask = anilist.listingAnime(from: listingReference)
                .error { _ in imageURL = NineAnimator.placeholderArtworkUrl }
                .finally {
                    animeInfo in
                    imageURL = animeInfo.artwork
                    animeSynopsis = animeInfo.description
                }
        }
        
        func openAnilistView() {
            let anilist = NineAnimator.default.service(type: Anilist.self)
            let listingReference = ListingAnimeReference(
                anilist,
                name: result.anilist.title.romaji ?? "Unknown Title",
                identifier: String(result.anilist.id),
                artwork: imageURL
            )
            
            let link = AnyLink.listingReference(listingReference)
            RootViewController.shared?.open(immedietly: link, method: .inCurrentlyDisplayedTab)
        }
    }
    
    struct AnimeDetailedInfoView: View {
        let result: TraceMoe.TraceMoeSearchResult
        @Binding var synopsis: String?
        
        var body: some View {
            VStack(alignment: .leading) {
                if let ep = result.episode?.value,
                   !ep.isEmpty {
                    Text("Episode: \(ep)")
                        .font(.subheadline)
                        .fontWeight(.light)
                }
                if let synopsis = synopsis {
                    Text(synopsis)
                        .font(.subheadline)
                        .fontWeight(.light)
                        .lineLimit(2)
                }
                Text("Similarity: \(Int(result.similarity * 100))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
    }
    
    struct SimilarAnimeView: View {
        let result: TraceMoe.TraceMoeSearchResult
        
        var body: some View {
            Button { openAnilistView() } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(result.anilist.title.english ?? "No English Title")
                            .font(.title3)
                            .lineLimit(2)
                        AnimeDetailedInfoView(result: result, synopsis: .constant(nil))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    LoopingVideoPlayer(videoURL: result.video)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            // Prevent button from changing text colour to accent colour
            .foregroundColor(.primary)
        }
        
        func openAnilistView() {
            let anilist = NineAnimator.default.service(type: Anilist.self)
            let listingReference = ListingAnimeReference(
                anilist,
                name: result.anilist.title.romaji ?? "Unknown Title",
                identifier: String(result.anilist.id)
            )
            
            let link = AnyLink.listingReference(listingReference)
            RootViewController.shared?.open(immedietly: link, method: .inCurrentlyDisplayedTab)
        }
    }
    
    struct AnimeTitlesView: View {
        let result: TraceMoe.TraceMoeSearchResult
        
        var body: some View {
            VStack(alignment: .leading) {
                Text(result.anilist.title.english ?? "No English Title")
                    .font(.title)
                    .lineLimit(2)
                    .padding(0)
                if let nativeTitle = result.anilist.title.native {
                    Text(nativeTitle)
                        .font(.subheadline)
                        .fontWeight(.light)
                        .lineLimit(1)
                        .foregroundColor(.gray)
                }
                if let romaji = result.anilist.title.romaji {
                    Text(romaji)
                        .font(.subheadline)
                        .fontWeight(.light)
                        .lineLimit(1)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}
