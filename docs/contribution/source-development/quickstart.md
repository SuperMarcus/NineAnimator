---
title: Source Development Quick Start
lang: en-US
---

# Source Development Quick Start

## Setting up Development Environment

> To build this app, you will need to have the latest version of Xcode installed. When contributing, **do not** include your team identifier.

1.  Create your own fork of the [NineAnimator](https://github.com/SuperMarcus/NineAnimator/) repository.

    To fork, in the top-right corner of the repository, click **Fork**.

2.  Clone your forked repository to your local machine.

    ```bash
    $ git clone https://github.com/YOUR-USERNAME/NineAnimator
    ```

3.  Open the repository in Xcode and modify the project settings (Bundle Identifier, Teams, and Capabilities.).

    ![Modify Xcode Project Settings](https://github.com/SuperMarcus/NineAnimator/raw/master/Misc/Media/modify_proj.gif)

    1. Navigate to the `NineAnimator` project file.
    2. Under the `General` tab, change part of the `Bundle Identifier` to any alphanumeric characters without whitespaces.
    3. Then navigate to the `Signing & Capabilities` tab. Select your team in the `Teams` drawer. If Xcode prompts you for the signing options, choose the one that let Xcode automatically manages signing.
    4. Scroll down in the `Signing & Capabilities` tab. Remove the associated domains capability.

4.  Build the app with Xcode

    You won't need any Apple Developer membership to build and install this app.

    Open this project in Xcode, connect your phone to the computer, select your
    device, and click the run button on the top left corner.

    ![Xcode select device](https://github.com/SuperMarcus/NineAnimator/raw/master/Misc/Media/xcode_select_device.jpg)

## Try and edit a Source (Optional)

Now that you have setup the development environment to contribute a source. You may try and modify an existing source to get a feel of how NineAnimator fetches data from different source anime websites, decodes it, and present the information to other components of NineAnimator.

We are going to use [`GogoAnime`](https://github.com/SuperMarcus/NineAnimator/tree/master/Modules/Sources/NineAnimatorNativeSources/AnimeSources/GogoAnime) as our example source. You may pick any other sources when following the tutorial below.

In a typical NineAnimator's source, there will be total of five files: `SourceName.swift`, `SourceName+Anime.swift`, `SourceName+Episode.swift`, `SourceName+Featured.swift`, `SourceName+Search.swift`. Each files are separated by it's functionality where `SourceName.swift` is the main distinct Source class, and the other files are the extension of the class.

In this section, you will making simple changes like changing the source's name and enabling/disabling the source.

As mentioned, the `SourceName.swift` is the main distinct Source class of an anime source. It conforms to the NineAnimatorCommon [`Source`](https://github.com/SuperMarcus/NineAnimatorCommon/blob/master/Sources/NineAnimatorCommon/Models/AnimeSource/Source.swift) protocol. The class accepts a few variables, one of them is the `isEnabled` variable. As you may have guessed, this variable controls whether the anime source is enabled or not.

To disable the anime source, you can change the value of the `isEnabled` variable to `false`. To change the name of the anime source, edit the `name` variable.

```diff
- var name: String { "gogoanime.tv" }
+ var name: String { "gogoanime.video" }

- override var isEnabled: Bool { true }
+ override var isEnabled: Bool { false }
```

Now, build and run the app in Xcode, and you should be able to see your changes in the app.
