---
title: Source Development
lang: en-US
---

# Source Development

## What should I know before I get started?

NineAnimator is a typical Cocoa Touch iOS application following the Model-View-Controller (MVC) design pattern. There are many resources online for you to learn the MVC design, but in short, you should know the responsibility of each component and keep the additional code at where it should be.

**Model**: NineAnimator, at its core, is a collection of parsers and analyzers. The [`Modules/Sources`](https://github.com/SuperMarcus/NineAnimator/tree/master/Modules/Sources) directory hosts all of the parsing logic and user-configurable.

- **Anime Source**: Under the `Modules/Sources` folder, you'll find the [`NineAnimatorNativeSources`](https://github.com/SuperMarcus/NineAnimator/tree/master/Modules/Sources/NineAnimatorNativeSources). Code under this folder fetches data from different source anime websites, decodes it, and present the information to other components of NineAnimator. For each source website, NineAnimator creates a distinct `Source` class. `Source` encapsulates the functionalities and capabilities of the anime website.
- **Media Parser**: Media Parsers, located under the [`NineAnimatorNativeParsers`](https://github.com/SuperMarcus/NineAnimator/tree/master/Modules/Sources/NineAnimatorNativeParsers) folder under `Modules/Sources`, are classes that accept a URL to a streaming site and return a locally streamable URL. Media Parsers are used to support playbacks with native players (and cast). NineAnimator parsers will conform to the `VideoProviderParser` protocol.

For development of sources, we are only going to touch the `Model`. More specifically, the [`NineAnimatorNativeSources`](https://github.com/SuperMarcus/NineAnimator/tree/master/Modules/Sources/NineAnimatorNativeSources) and [`NineAnimatorNativeParsers`](https://github.com/SuperMarcus/NineAnimator/tree/master/Modules/Sources/NineAnimatorNativeParsers) directories.

## Where do I start?

Developing a source is pretty easy, you only need basic programming knowledge. Some understanding of git may help but is not required.

- Validate that the website you intend to write for is not already available. A list of sources can be found on the [supported sources list](/guide/supported-sources).

- Check out the [quickstart](quickstart/) guide for a place to begin.

- Use on of our guide and tutorial to learn more about source development:
  - [Source Development Quickstart](quickstart/)
  - [A Guide to Parse Data](parsing-guide/)
  - [Function Definitions](function-definitions/)
  - [Model Reference](model-reference/)
