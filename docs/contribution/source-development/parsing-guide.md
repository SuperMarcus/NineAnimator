---
title: A guide to scrape and parse data
lang: en-US
---

# A guide to scrape and parse data

NineAnimator uses the [SwiftSoup](https://github.com/scinfu/SwiftSoup) library for working with HTML. By using DOM traversal or CSS selectors, it enable us to find and extract data from a website.

If you are not familiar with using CSS selectors, it is recommend that you try out the simple SwiftSoup CSS selectors site: [SwiftSoup Test Site](https://swiftsoup.herokuapp.com/).

## Quick Reference Guide

### The Basics

```swift
let html: String = """
<html>
  <head>
    <title>Try SwiftSoup</title>
  </head>
  <body>
    <p>This is a SwiftSoup test page</p>
    <a href='http://example.com/'>Some example link</a>
  </body>
</html>
""";
let doc: Document = try SwiftSoup.parse(html)
let paragraph: Element = try doc.select("p").first()!
let link: Element = try doc.select("a").first()!

let bodyText: String = try doc.body()!.text();
// "This is a SwiftSoup test page Some example link"

let paragraphText: String = try paragraph.text();
// "This is a SwiftSoup test page"

let linkHref: String = try link.attr("href");
// "http://example.com/"

let linkText: String = try link.text();
// "Some example link"
```

### Advanced Selectors

## A NineAnimator Parsing Example

<CodeGroup>
  <CodeGroupItem title="GogoAnime+Featured.swift">

```swift{10,12,15-18,33,37}
extension NASourceGogoAnime {
    // ...
    fileprivate var latestAnimeUpdates: NineAnimatorPromise<[AnimeLink]> {
        // Browse home
        return requestManager.request("/", handling: .browsing)
            .responseString
            .then {
                content -> [AnimeLink] in
                Log.info("Loading GogoAnime ongoing releases page")
                let bowl = try SwiftSoup.parse(content)
                return try bowl
                    .select(".last_episodes>ul>li")
                    .compactMap {
                        item -> AnimeLink? in
                        let linkContainer = try item.select(".img>a")

                        // The link is going to be something like '/xxx-xxxx-episode-##'
                        let episodePath = try linkContainer.attr("href")

                        // Match the anime identifier with regex
                        let animeIdentifierMatches = NASourceGogoAnime
                            .animeLinkFromEpisodePathRegex
                            .matches(in: episodePath, options: [], range: episodePath.matchingRange)
                        guard let animeIdentifierMatch = animeIdentifierMatches.first else { return nil }
                        let animeIdentifier = episodePath[animeIdentifierMatch.range(at: 1)]

                        // Reassemble the anime URL to something like '/category/xxx-xxxx'
                        guard let animeUrl = URL(string: "\(self.endpoint)/category/\(animeIdentifier)") else {
                            return nil
                        }

                        // Read the link to the artwork
                        guard let artworkUrl = URL(string: try linkContainer.select("img").attr("src")) else {
                            return nil
                        }

                        let animeTitle = try item.select("p.name").text()

                        return AnimeLink(
                            title: animeTitle,
                            link: animeUrl,
                            image: artworkUrl,
                            source: self
                        )
                }
        }
    }
    // ...
}
```

  </CodeGroupItem>

  <CodeGroupItem title="site.html">

```html
<div class="last_episodes loaddub">
  <ul class="items">
    <li>
      <div class="img">
        <a
          href="/boruto-naruto-next-generations-episode-237"
          title="Boruto: Naruto Next Generations"
        >
          <img
            src="https://example.com/cover/boruto-naruto-next-generations.png"
            alt="Boruto: Naruto Next Generations"
          />
          <div class="type ic-SUB"></div>
        </a>
      </div>
      <p class="name">
        <a
          href="/boruto-naruto-next-generations-episode-237"
          title="Boruto: Naruto Next Generations"
          >Boruto: Naruto Next Generations</a
        >
      </p>
      <p class="episode">Episode 237</p>
    </li>
  </ul>
</div>
```

  </CodeGroupItem>
</CodeGroup>
