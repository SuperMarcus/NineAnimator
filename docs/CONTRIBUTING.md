## Contributing to NineAnimator

First and foremost, thank you for taking the time to read this document. We are a community of developers and anime lovers, and we need people like you to help in the development of this project.

If you haven't joined our [Discord server](https://discord.gg/dzTVzeW) already, feel free to come and find us [there](https://discord.gg/dzTVzeW). You'll get faster responses from our community members and contributors.

In this document, you'll find a set of guidelines for contributing and some resources for getting familiar with NineAnimator's code.

### Table of Contents

- [I just have a question](#i-just-have-a-question)
- [How can I contribute?](#how-can-i-contribute)
- [What should I know before I get started?](#what-should-i-know-before-i-get-started)
    - [Model View Controller](#model-view-controller)
    - [Asynchronous](#asynchronous)
- [Styleguides](#styleguides)
    - [Git Commits](#git-commits)
    - [Swift Styleguide](#swift-styleguide)
- [Contributing Assets](#contributing-assets)

### I just have a question

For faster responses, use our [Discord server](https://discord.gg/dzTVzeW) for questions.
* Chances are your question has been answered by one of our moderators. Make sure to check the `#faq` channel and the pinned messages in the `#general` and `#app-support` channels.
* If you can't find what you're looking for, post your inquiry in the `#app-support` channel.

Optionally, you can also use our [r/NineAnimator](https://reddit.com/r/NineAnimator) subreddit.

### How can I contribute?

* **Report Bugs**: Use the [issue tracker](https://github.com/SuperMarcus/NineAnimator/issues/new/choose) with the `Bug Report` template to report a bug.
* **Suggesting Enhancements**: Use the [issue tracker](https://github.com/SuperMarcus/NineAnimator/issues/new/choose) with the `Feature Request` template to suggest an enhancement.
* **Help Translating the App**: Use our [Crowdin site](https://translate.9ani.app) at [https://translate.9ani.app](https://translate.9ani.app) to help translate NineAnimator into different languages.
* **Code Contribution**: Whether you implemented a new anime source or fixed a bug, feel free to open a pull request from your fork. Make sure you read the [styleguides](#styleguides) section.
* **Assets & Designs**: Creating a new app icon for NineAnimator? Have suggestions on the designs? See the [Contributing Assets](#contributing-assets) section.

Feel free to talk to us on our [Discord server](https://discord.gg/dzTVzeW) before contributing.

### What should I know before I get started?

#### Model View Controller

NineAnimator is a typical Cocoa Touch iOS application following the Model-View-Controller (MVC) design pattern. There are many resources online for you to learn the MVC design, but in short, you should know the responsibility of each component and keep the additional code at where it should be.

**Model**: NineAnimator, at its core, is a collection of parsers and analyzers. The [`Modules/Sources`](https://github.com/SuperMarcus/NineAnimator/tree/master/Modules/Sources) directory hosts all of the parsing logic and user-configurable.
* **Anime Source**: Under the `Modules/Sources` folder, you'll find the [`NineAnimatorNativeSources`](https://github.com/SuperMarcus/NineAnimator/tree/master/Modules/Sources/NineAnimatorNativeSources). Code under this folder fetches data from different source anime websites, decodes it, and present the information to other components of NineAnimator. For each source website, NineAnimator creates a distinct `Source` class. `Source` encapsulates the functionalities and capabilities of the anime website.
* **Media Parser**: Media Parsers, located under the [`NineAnimatorNativeParsers`](https://github.com/SuperMarcus/NineAnimator/tree/master/Modules/Sources/NineAnimatorNativeParsers) folder under `Modules/Sources`, are classes that accept a URL to a streaming site and return a locally streamable URL. Media Parsers are used to support playbacks with native players (and cast). NineAnimator parsers will conform to the `VideoProviderParser` protocol.
* **Anime Listing Service**: The list services are third-party tracking and information services implemented under the [`NineAnimatorNativeListServices`](https://github.com/SuperMarcus/NineAnimator/tree/master/Modules/Sources/NineAnimatorNativeListServices) folder under `Modules/Sources`. List services conform to the `ListingService` protocol and declare their capabilities through the `var isCapableOf<capability>: Bool` getters. List services also provide the matching `ListingAnimeReference` for each `AnimeLink`.

**View**: The views define the look and feel of the UI components. NineAnimator employs several mechanisms to construct and configure the UI. In general, NineAnimator's design follows that of the latest iOS system apps.
* **Storyboards and Xibs**: NineAnimator defines most of the UIs with storyboards. We also use auto-layout extensively for adaptive layouts and device variants.
* **Theme**: Although iOS 13 introduced the system-wide dark mode, to enable backward compatibility with older systems, we still employ our own theming system for light and dark appearances. Each UI component is manually added by `Theme.provision()` (or, for subclasses of `UIView`, `.makeThemable()`). Subclasses of `UIView` can either implicitly or explicitly support the theming system. By default, the theming system will configure the views according to types. By conforming to the `Themable` protocol, you're explicitly stating support for the theme system and waiving the default behaviors.

**Controllers**: Controllers of NineAnimator manages the internal flow and logics.
* **View Controllers**: View controllers instantiate and manage views. In most cases, there will be a convenient method for instantiating view controllers. Optionally, view controllers are also linked by storyboard references. The following is a list of common view controllers in NineAnimator.
    * **AnimeViewController**: The `AnimeViewController` class fetches and presents the correspond `Anime` object of an `AnimeLink`. Create the `AnimeViewController` using storyboard, then use the `setPresenting()` method to configure.
    * **NativePlayerController**: The `NativePlayerController` class manages local playbacks of the retrieved `PlaybackMedia` instances. You don't instantiate `NativePlayerController` directly. Instead, you use the `NativePlayerController.default` singleton to retrieve the shared instance and call the `play()` method to start playback.
    * **CastController**: The `CastController` manages external playbacks such as Google Cast. Use `CastController.default` to retrieve the singleton. Use the `presentPlaybackController()` to present the casting interface. Use the `var isReady: Bool` getter to check if a device has been selected and is ready for playback.
* **UserNotificationManager**: The `UserNotificationManager` manages and update anime subscriptions. Use the `UserNotificationManager.default` singleton to retrieve the shared manager.
* **OfflineContentManager**: The `OfflineContentManager` hosts NineAnimator's download system. Use the `OfflineContentManager.shared` singleton to access the shared manager.

#### Asynchronous

Most operations in NineAnimator are performed asynchronously (optionally on a different thread). This ensures that any time consuming or intensive tasks won't block the main thread.

At the center of NineAnimator's asynchronous framework is the [`NineAnimatorPromise` class](https://github.com/SuperMarcus/NineAnimatorCommon/blob/master/Sources/NineAnimatorCommon/Utilities/Asynchronous/Promise.swift). This class borrows the idea of promise and bridges the legacy callback mechanisms.

> Note: As a safety measure, be sure to maintain a reference to the promise instance for the duration of the task. Losing reference to an unresolved promise will result in the executing task being cancelled. Inside the promise, all references to the blocks or tasks will be removed as soon as the promise task returns.

```Swift
let promise = NineAnimatorPromise.firstly {
    () -> Int in
    var result: Int
    // Pefrom some operations...
    return result
} .then {
    previousResult -> Int in
    var result: Int
    // Some additional operations...
    return result
} .thenPromise {
    previousResult -> NineAnimatorPromise<Int> in
    // Return a promise
    .firstly {
        var result: Int
        // Perform some more operations...
        return result
    }
} .defer {
    thisPromise in
    // This block is executed whenever the promises to this point finish
    // executing, regardless of success or failiure.
} .error {
    error in
    // Called when the promise is rejected with an error
} .finally {
    finalResult in
    // Called when the promise is resolved (successfully)
    // All previous promises are not executed until the `finally` block
    // is added.
}
```

### Styleguides

#### Git Commits

In general, use descriptive languages for commit messages. Explain what you add, changed, or deleted ("Fix a problem that causes the app to crash in the Library scene" not "fix a problem"). Reference any issue if the commit is related to one.

Before committing, make sure the compiler doesn't complain and `swiftlint` doesn't give out warnings.

Avoid trivial ("Oops!") commits. Whenever possible, amend your existing commits before pushing or submitting a pull request.

Do as much as related in a single commit. For example, if you're renaming a list of files, don't commit for each rename operation. Instead, commit once for all name changes.

#### Swift Styleguide

A few points to keep in mind:

* Use implicit returns for single-line functions and closures.
* Avoid implicit unwrapping properties and variables (`var data: Data! { get }`).
* Prefer shorter class names (`LibrarySceneController` not `LibraryTabSceneCollectionViewController`).
* Prefer extensions over single files. Split large files into multiple smaller files with `+` extensions (ex. `User.swift`, `User+Preferences.swift`, `User+History.swift`).

We use `swiftlint` to ensure the tidiness of our code. Before submitting your code, run `swiftlint` to check for potential styling violations.

### Contributing Assets

Please use our [Discord server](https://discord.gg/dzTVzeW) for suggestions related to UI designs and visual
experiences.

* **App Icon Submissions**: please submit your design to the #app-icon-suggestions channel. Community-contributed app icons should be rendered with a resolution of 180x180 or higher.
* **Visuals & Designs**: please send your design or suggestions to the #suggestions channel.
