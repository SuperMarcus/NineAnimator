---
title: Function Definitions
lang: en-US
---

# Function Definitions

NineAnimatorCommon [`AnimeSource/Source.swift`](https://github.com/SuperMarcus/NineAnimatorCommon/blob/master/Sources/NineAnimatorCommon/Models/AnimeSource/Source.swift) function definitions.

## featured

### Method signature

```swift
func featured(_ handler: @escaping NineAnimatorCallback<FeaturedContainer>) -> NineAnimatorAsyncTask?
```

### Parameters

| Parameter | Type                                      | Description |
| --------- | ----------------------------------------- | ----------- |
| `handler` | NineAnimatorCallback\<FeaturedContainer\> | NIL FOR NOW |

### Returns

NineAnimatorAsyncTask

### Example Implementation

```swift
 /// Implementation for the new featured page
fileprivate func featured() -> NineAnimatorPromise<FeaturedContainer> {
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

## anime

### Method signature

```swift
func anime(from link: AnimeLink, _ handler: @escaping NineAnimatorCallback<Anime>) -> NineAnimatorAsyncTask?
```

### Parameters

| Parameter | Type                                      | Description |
| --------- | ----------------------------------------- | ----------- |
| `handler` | NineAnimatorCallback\<FeaturedContainer\> | NIL FOR NOW |

### Returns

NineAnimatorAsyncTask

## episode

### Method signature

```swift
func episode(from link: EpisodeLink, with anime: Anime, _ handler: @escaping NineAnimatorCallback<Episode>) -> NineAnimatorAsyncTask?
```

### Parameters

| Parameter | Type                                      | Description |
| --------- | ----------------------------------------- | ----------- |
| `handler` | NineAnimatorCallback\<FeaturedContainer\> | NIL FOR NOW |

### Returns

NineAnimatorAsyncTask

## search

### Method signature

```swift
func search(keyword: String) -> ContentProvider
```

### Parameters

| Parameter | Type                                      | Description |
| --------- | ----------------------------------------- | ----------- |
| `handler` | NineAnimatorCallback\<FeaturedContainer\> | NIL FOR NOW |

### Returns

NineAnimatorAsyncTask

## suggestProvider

### Method signature

```swift
func suggestProvider(episode: Episode, forServer server: Anime.ServerIdentifier, withServerName name: String) -> VideoProviderParser?
```

### Parameters

| Parameter | Type                                      | Description |
| --------- | ----------------------------------------- | ----------- |
| `handler` | NineAnimatorCallback\<FeaturedContainer\> | NIL FOR NOW |

### Returns

NineAnimatorAsyncTask

## link

### Method signature

```swift
func link(from url: URL, _ handler: @escaping NineAnimatorCallback<AnyLink>) -> NineAnimatorAsyncTask?
```

### Parameters

| Parameter | Type                                      | Description |
| --------- | ----------------------------------------- | ----------- |
| `handler` | NineAnimatorCallback\<FeaturedContainer\> | NIL FOR NOW |

### Returns

NineAnimatorAsyncTask

## canHandle

### Method signature

```swift
/// Return true if this source supports translating contents
/// from the provided URL
func canHandle(url: URL) -> Bool
```

### Parameters

| Parameter | Type                                      | Description |
| --------- | ----------------------------------------- | ----------- |
| `handler` | NineAnimatorCallback\<FeaturedContainer\> | NIL FOR NOW |

### Returns

NineAnimatorAsyncTask

## recommendServer

### Method signature

```swift
/// Recommend a preferred server for the anime object
func recommendServer(for anime: Anime) -> Anime.ServerIdentifier?
```

### Parameters

| Parameter | Type                                      | Description |
| --------- | ----------------------------------------- | ----------- |
| `handler` | NineAnimatorCallback\<FeaturedContainer\> | NIL FOR NOW |

### Returns

NineAnimatorAsyncTask

## recommendServers

### Method signature

```swift
/// Recommend a list of servers (ordered from the best to the worst) for a particular purpose
func recommendServers(for anime: Anime, ofPurpose: VideoProviderParser.Purpose) -> [Anime.ServerIdentifier]
```

### Parameters

| Parameter | Type                                      | Description |
| --------- | ----------------------------------------- | ----------- |
| `handler` | NineAnimatorCallback\<FeaturedContainer\> | NIL FOR NOW |

### Returns

NineAnimatorAsyncTask
