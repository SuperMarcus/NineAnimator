---
title: Source Development
lang: en-US
---

# Source Development

## What should I know before I get started?

NineAnimator is a typical Cocoa Touch iOS application following the Model-View-Controller (MVC) design pattern. There are many resources online for you to learn the MVC design, but in short, you should know the responsibility of each component and keep the additional code at where it should be.

**Model**: NineAnimator, at its core, is a collection of parsers and analyzers. The [`Modules/Sources`](https://github.com/SuperMarcus/NineAnimator/tree/master/Modules/Sources) directory hosts all of the parsing logic and user-configurable.

**View**: The views define the look and feel of the UI components. NineAnimator employs several mechanisms to construct and configure the UI. In general, NineAnimator's design follows that of the latest iOS system apps.

**Controllers**: Controllers of NineAnimator manages the internal flow and logics.

For development of sources, we are only going to touch the `Model`. More specifically, the [`NineAnimatorNativeSources`](https://github.com/SuperMarcus/NineAnimator/tree/master/Modules/Sources/NineAnimatorNativeSources) and [`NineAnimatorNativeParsers`](https://github.com/SuperMarcus/NineAnimator/tree/master/Modules/Sources/NineAnimatorNativeParsers) directories.

## Where do I start?

Developing a source is pretty easy, you only need basic programming knowledge. Some understanding of git may help but is not required.

- Validate that the website you intend to write for is not already available. A list of sources can be found on the [supported sources list](/guide/supported-sources).

- Check out the [quickstart](quickstart/) guide for a place to begin.

- Use on of our guide and tutorial to learn more about source development:
  - [Source development quickstart](quickstart/)
  - [A practical guide to Parsing](parsing-guide/)
  - [Class definitions](class-definitions/)
  - [Function definitions](function-definitions/)
