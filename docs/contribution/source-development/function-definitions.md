---
title: Function Definitions
lang: en-US
sidebarDepth: 1
---

# Function Definitions

See NineAnimatorCommon [`AnimeSource/Source.swift`](https://github.com/SuperMarcus/NineAnimatorCommon/blob/master/Sources/NineAnimatorCommon/Models/AnimeSource/Source.swift) function definitions for implementation.

## `featured`

### Method signature

```swift
func featured(_ handler: @escaping NineAnimatorCallback<FeaturedContainer>) -> NineAnimatorAsyncTask?
```

### Parameters

| Parameter | Type                                      | Description           |
| --------- | ----------------------------------------- | --------------------- |
| `handler` | NineAnimatorCallback\<FeaturedContainer\> | An optional parameter |

### Returns

The featured function return a `NineAnimatorAsyncTask`. In a source implementation, the function should return [`NineAnimatorPromise<FeaturedContainer>`](/contribution/source-development/function-reference#featuredcontainer).

### Example Implementation

```swift
func featured() -> NineAnimatorPromise<FeaturedContainer> {
    self.requestManager
        .request("/", handling: .browsing)
        .responseString
        .then { content -> FeaturedContainer in
            Log.info("[NASourceGogoAnime] Loading FeaturedContainer")

              // Parse html contents
              let bowl = try SwiftSoup.parse(content)

            // Links for updated anime
            let updatedAnimeContainer = try bowl.select(".new-latest")
            let latestAnime = try updatedAnimeContainer.select(".nl-item").map {
                element -> AnimeLink in
                let urlString = try element.select("a.nli-image").attr("href")
                let url = try URL(string: urlString).tryUnwrap(.urlError)
                let artwork = try element.select("img").attr("src")
                let artworkUrl = try URL(string: artwork).tryUnwrap(.urlError)
                let title = try element.select("nli-serie").text()
                return AnimeLink(title: title, link: url, image: artworkUrl, source: self)
            }

            // Links for popular anime
            let popularAnimeContainer = try bowl.select(".ci-contents .bl-box").map {
                element -> AnimeLink in
                let linkElement = try element.select("a.blb-title")
                let title = try linkElement.text()
                let urlString = try linkElement.attr("href")
                let url = try URL(string: urlString).tryUnwrap(.urlError)
                let artwork = try element.select(".blb-image>img").attr("src")
                let artworkUrl = try URL(string: artwork).tryUnwrap(.urlError)
                return AnimeLink(title: title, link: url, image: artworkUrl, source: self)
            }

            // Construct a basic featured anime container
            return BasicFeaturedContainer(
                featured: popularAnimeContainer,
                latest: latestAnime
            )
        }
}
```

## `anime`

### Method signature

```swift
func anime(from link: AnimeLink, _ handler: @escaping NineAnimatorCallback<Anime>) -> NineAnimatorAsyncTask?
```

### Parameters

| Parameter | Type                          | Description                                          |
| --------- | ----------------------------- | ---------------------------------------------------- |
| `link`    | AnimeLink                     | The `AnimeLink` object struct for all possible links |
| `handler` | NineAnimatorCallback\<Anime\> | NineAnimatorCallback for Anime                       |

### Returns

The anime function return a `NineAnimatorAsyncTask`. In a source implementation, the function should return [`NineAnimatorPromise<Anime>`](/contribution/source-development/function-reference#anime).

### Example Implementation

```swift
func anime(from link: AnimeLink) -> NineAnimatorPromise<Anime> {
    self.requestManager
        .request(url: link.link, handling: .browsing)
        .responseString
        .then {
            responseContent -> Anime in
            let bowl = try SwiftSoup.parse(responseContent)
            let animeTitle = try bowl.select("div.container.anime-title-as.mb-3.w-100 b").text()
            let animeArtworkUrl = URL(
                string: try bowl.select(".cover>img").attr("src")
                ) ?? link.image
            let reconstructedAnimeLink = AnimeLink(
                title: animeTitle,
                link: link.link,
                image: animeArtworkUrl,
                source: self
            )

            // Obtain the list of episodes
            let episodes = try bowl.select("div.tab-content div div.episodes-button").reduce(into: [EpisodeLink]()) {
                collection, container in
                let name =  try container.select("a").text().components(separatedBy: " ")
                let episodeName = name[1]
                var episodeLink = try container.select("a").attr("href")
                episodeLink = episodeLink.replacingOccurrences(of: "'", with: "\'")
                if !episodeLink.isEmpty {
                    collection.append(.init(
                        identifier: episodeLink,
                        name: episodeName,
                        server: NASourceAnimeSaturn.AnimeSaturnStream,
                        parent: reconstructedAnimeLink
                        ))
                }
            }

            // Information
            let alias = try bowl.select("div.box-trasparente-alternativo.rounded").first()?.text()
            let animeSynopsis = try bowl.select("#shown-trama").text()
            // var additionalAttributes = [Anime.AttributeKey: Any]()
            // Attributes
            let additionalAttributes = try bowl.select("div.container.shadow.rounded.bg-dark-as-box.mb-3.p-3.w-100.text-white").reduce(into: [Anime.AttributeKey: Any]()) { attributes, entry in
                let info = try entry.html().components(separatedBy: "<br>")
                for elem in info {
                    if elem.contains("<b>Voto:</b> ") {
                        var rat = elem.components(separatedBy: "<b>Voto:</b> ")
                        rat = rat[safe: 1]?.components(separatedBy: "/") ?? []
                        let rating = ((rat[safe: 0] ?? "") as NSString).floatValue
                        attributes[.rating] = rating
                        attributes[.ratingScale] = Float(5.0)
                    }
                    if elem.contains("<b>Data di uscita:</b> ") {
                        let rat = elem.components(separatedBy: "<b>Data di uscita:</b> ")
                        let airdate = rat[safe: 1]
                        attributes[.airDate] = airdate
                    }
                }
            }

            return Anime(
                reconstructedAnimeLink,
                alias: alias ?? animeTitle,
                additionalAttributes: additionalAttributes,
                description: animeSynopsis,
                on: [ NASourceAnimeSaturn.AnimeSaturnStream: "AnimeSaturn" ],
                episodes: [ NASourceAnimeSaturn.AnimeSaturnStream: episodes ],
                episodesAttributes: [:]
            )
        }
}
```

## `episode`

### Method signature

```swift
func episode(from link: EpisodeLink, with anime: Anime, _ handler: @escaping NineAnimatorCallback<Episode>) -> NineAnimatorAsyncTask?
```

### Parameters

| Parameter | Type                            | Description                                                                   |
| --------- | ------------------------------- | ----------------------------------------------------------------------------- |
| `link`    | EpisodeLink                     | The `EpisodeLink` information of an episode                                   |
| `with`    | Anime                           | The Anime object represents a collection of information about the `AnimeLink` |
| `handler` | NineAnimatorCallback\<Episode\> | NineAnimatorCallback for Episode                                              |

### Returns

The episode function return a `NineAnimatorAsyncTask`. In a source implementation, the function should return [`NineAnimatorPromise<Episode>`](/contribution/source-development/function-reference#episode).

### Example Implementation

```swift
func episode(from link: EpisodeLink, with anime: Anime) -> NineAnimatorPromise<Episode> {
        requestManager.request(url: link.identifier)
            .responseBowl
            .then {
                bowl in
                let iFrameURL = try URL(string: bowl
                    .select("#iframe-to-load")
                    .attr("src"))
                    .tryUnwrap()

                return Episode(
                    link,
                    target: iFrameURL,
                    parent: anime
                )
            }
    }
```

## `search`

### Method signature

```swift
func search(keyword: String) -> ContentProvider
```

### Parameters

| Parameter | Type   | Description      |
| --------- | ------ | ---------------- |
| `keyword` | String | The search query |

### Returns

ContentProvider

## `suggestProvider`

### Method signature

```swift
func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser?
```

### Parameters

| Parameter        | Type                   | Description                                                               |
| ---------------- | ---------------------- | ------------------------------------------------------------------------- |
| `episode`        | Episode                | The Episode object is a struct that wraps information of an anime episode |
| `forServer`      | Anime.ServerIdentifier | An array of the Anime struct ServerIdentifier                             |
| `withServerName` | String                 | The server name selected                                                  |

### Returns

VideoProviderParser

### Example Implementation

```swift
func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser? {
    VideoProviderRegistry.default.provider(for: name)
}
```

## `link`

### Method signature

```swift
func link(from url: URL, _ handler: @escaping NineAnimatorCallback<AnyLink>) -> NineAnimatorAsyncTask?
```

### Parameters

| Parameter | Type                            | Description                      |
| --------- | ------------------------------- | -------------------------------- |
| `url`     | URL                             | The URL of the anime site        |
| `handler` | NineAnimatorCallback\<AnyLink\> | NineAnimatorCallback for AnyLink |

### Returns

The link function return a `NineAnimatorAsyncTask`. In a source implementation, the function should return `NineAnimatorPromise<AnyLink>`.

## `canHandle`

### Method signature

```swift
func canHandle(url: URL) -> Bool
```

### Parameters

| Parameter | Type | Description |
| --------- | ---- | ----------- |
| `url`     | URL  | NIL         |

### Returns

Given a url, this function should return a `boolean` value. If the source supports translating contents, it should return true from the provided URL.

## `recommendServer`

Recommend a preferred server for the anime object

### Method signature

```swift
func recommendServer(for anime: Anime) -> Anime.ServerIdentifier?
```

### Parameters

| Parameter | Type  | Description                                                                   |
| --------- | ----- | ----------------------------------------------------------------------------- |
| `for`     | Anime | The Anime object represents a collection of information about the `AnimeLink` |

### Returns

Anime.ServerIdentifier

### Example Implementation

```swift
func recommendServer(for anime: Anime) -> Anime.ServerIdentifier? {
    recommendServers(for: anime, ofPurpose: .playback).first
}
```

## `recommendServers`

### Method signature

Recommend a list of servers (ordered from the best to the worst) for a particular purpose

```swift
func recommendServers(for anime: Anime, ofPurpose: VideoProviderParser.Purpose) -> [Anime.ServerIdentifier]
```

### Parameters

| Parameter   | Type                        | Description                                                                   |
| ----------- | --------------------------- | ----------------------------------------------------------------------------- |
| `for`       | Anime                       | The Anime object represents a collection of information about the `AnimeLink` |
| `ofPurpose` | VideoProviderParser.Purpose | The purpose of the selection of parser, streaming or downloading              |

### Returns

This function should return an array of servers (ordered from the best to the worst). The return type is \[Anime.ServerIdentifier\].

### Example Implementation

```swift
func recommendServers(for anime: Anime, ofPurpose purpose: VideoProviderParserParsingPurpose) -> [Anime.ServerIdentifier] {
    ["server1", "server2", "server3", "server4"]
}
```
