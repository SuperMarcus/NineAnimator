---
title: A Guide to Parse Data
lang: en-US
---

# A Guide to Parse Data

NineAnimator uses the [SwiftSoup](https://github.com/scinfu/SwiftSoup) library for working with HTML. By using DOM traversal or CSS selectors, it enable us to find and extract data from a website.

If you are not familiar with using CSS selectors, it is recommend that you try out the simple SwiftSoup CSS selectors site: [SwiftSoup Test Site](https://swiftsoup.herokuapp.com/). If you are familiar with how to use SwiftSoup and understand the basic of CSS selectors, you may skip to [A NineAnimator Parsing Example](#a-nineanimator-parsing-example).

## Quick Reference Guide

### The Basics

#### Element name

The element selector selects HTML elements based on name.

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

#### Classes and Id

The id selector uses the id attribute of an HTML element to select a specific element.
The class selector selects HTML elements with a specific class attribute.

```swift
let html: String = """
<html>
  <head>
    <title>Try SwiftSoup</title>
  </head>
  <body>
    <p id="foo">weakness</p>
    <p id="bar">camera</p>
    <p id="foobar" class="common">offense</p>
    <p id="baz" class="common">stumble</p>
  </body>
</html>
""";
let doc: Document = try SwiftSoup.parse(html)
let paragraph: Element = try doc.select("p")

let paragraphTextOne: String = try paragraph.select("#foo").text();
// "weakness"

let paragraphTextTwo: String = try paragraph.select("#foobar").text();
// "offense"

let paragraphTextClass: String = try paragraph.select(".common").text();
// "offense stumble"
```

### Advanced Selectors

#### Combinators

The combinators selectors is used to select HTML elements based on a specific relationship between them. Refer to [combinators](https://developer.mozilla.org/en-US/docs/Learn/CSS/Building_blocks/Selectors/Combinators) for the complete list of combinators selectors.

There are four different combinators in CSS:

- descendant selector (space)
- child selector (>)
- adjacent sibling selector (+)
- general sibling selector (~)

```swift
let html: String = """
<html>
  <head>
    <title>Try SwiftSoup</title>
  </head>
  <body>
    <div id="foo">
      <p id="bar">camera</p>
      <p id="foobar" class="common">offense</p>
      <a href='http://example.com/'>Some example link</a>
    </div>
  </body>
</html>
""";
let doc: Document = try SwiftSoup.parse(html)
let body: Element = try doc.select("body")

let paragraphTextOne: String = try body.select("div > p").text();
// "camera offense"

let paragraphTextTwo: String = try body.select("p + p").text();
// "offense"

let linkHref: String = try body.select("#foo a").attr("href");
// "http://example.com/"
```

#### Attribute

The \[attribute\] selector is used to select elements with a specified attribute. Refer to [Attribute selectors](https://developer.mozilla.org/en-US/docs/Web/CSS/Attribute_selectors) for the complete list of attribute selectors.

```swift
let html: String = """
<html>
  <head>
    <title>Try SwiftSoup</title>
  </head>
  <body>
    <div lang="en-us en-gb en-au en-nz">Hello World!</div>
    <div lang="pt">Olá Mundo!</div>
    <div lang="zh-CN">世界您好！</div>
  </body>
</html>
""";
let doc: Document = try SwiftSoup.parse(html)
let body: Element = try doc.select("body")

let paragraphTextOne: String = try body.select("div[lang='pt']").text();
// "Olá Mundo!"
```

## A NineAnimator Parsing Example

The same concept apply when parsing data in NineAnimator using SwiftSoup. As mentioned, most operations in NineAnimator are performed asynchronously with NineAnimator's asynchronous framework: [`NineAnimatorPromise` class](https://github.com/SuperMarcus/NineAnimatorCommon/blob/master/Sources/NineAnimatorCommon/Utilities/Asynchronous/Promise.swift). The example below shows how to parse data for the `AnimeSource+Featured.swift` file using NineAnimatorPromise.

::: tip
NineAnimator provides useful utilities to help you parse the html and return a `Document` object: `responseBowl` when making a requests with NineAnimator's `requestManager`. This means you do not need to do `SwiftSoup.parse(htmlString)`.
:::

<CodeGroup>
  <CodeGroupItem title="GogoAnime+Featured.swift">

```swift{12,16,20,36,42}
extension NASourceGogoAnime {
    // ...
    fileprivate var latestAnimeUpdates: NineAnimatorPromise<[AnimeLink]> {
        // Browse home
        return requestManager.request("/", handling: .browsing)
            .responseBowl
            .then {
                bowl -> [AnimeLink] in
                Log.info("Loading GogoAnime ongoing releases page")
                return try bowl
                    // Selecting all the <a> element that is the direct child of elements with the "img" class
                    .select(".last_episodes>ul>li")
                    .compactMap {
                        item -> AnimeLink? in
                        // Selecting all the <a> element that is the direct child of elements with the "img" class
                        let linkContainer = try item.select(".img>a")

                        // Getting the link by retrieving the "href" attribute of the linkContainer
                        // "/boruto-naruto-next-generations-episode-237"
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
                        // "https://example.com/cover/boruto-naruto-next-generations.png"
                        guard let artworkUrl = URL(string: try linkContainer.select("img").attr("src")) else {
                            return nil
                        }

                        // Selecting all the <p> elements with the class "name" from that are in the ".last_episodes>ul>li"
                        // "Boruto: Naruto Next Generations"
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
    <!-- .last_episodes > ul > li -->
    <li>
      <div class="img">
        <!-- .img > a -->
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
      <!-- p.name -->
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
