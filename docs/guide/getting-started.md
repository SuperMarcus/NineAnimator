---
title: Getting Started
lang: en-US
---

# Getting Started

## Features

- Ads Free and no logins
- Super-duper clean UIs + Dark Mode
- Get notifications when new episodes come out
- Apple's native video playback interface
- Picture in Picture playback on iPads/iOS 14+ devices
- Chromecast/Google Cast with lockscreen & control center support
- Playback History & Auto Resumes
- Support [Multiple Anime Websites](supported-sources.md)
- Integration with HomeKit
- Discord Rich Presence integration (macOS only)
- Handoff & Siri Shortcuts
- Download & play episodes offline
- Third party anime [listing & tracking websites](third-party-lists.md) (view & edit)
- Custom anime lists, e.g. favorites and to-watch list (currently retrieved from tracking websites; mutations are work-in-progress)

### Google Cast

NineAnimator supports playing back on both AirPlay (via Apple's native media player) and
Chromecast/Google Cast devices. However, not all of the steaming sources are supported
on Chromecast. Check [Video Sources](supported-sources.md) for details.

To use Google Cast in NineAnimator, tap on the Google Cast icon on the navigation bar.
A window will pop up to prompt you to select a playback device. Once the device is
connected, click "Done" and select an episode from the episode list. The video will
starts playing automatically on the Google Cast device.

The playback control interface will appear once the playback starts. You may use the
volume up/down buttons to adjust the volume.

To disconnect from a Google Cast device, tap on the Google Cast icon on the navigation
bar and tap the device that is already connected.

### Picture in Picture Playback

This feature is only supported on iPads, Macs, and iOS 14+ devices.

The Picture in Picture (PiP) icon will appear on the top left corner of the player once PiP
is ready. You may tap on this icon to initiate PiP playback. To restore fullscreen playback,
tap the restore button on the PiP window.

### Notifications & Subscription

Subscribing anime in NineAnimator is implemented with Apple's Background Application
Refresh. NineAnimator will actively poll the available episodes and compares it with
locally cached episodes.

<img src="https://github.com/SuperMarcus/NineAnimator/raw/master/Misc/Media/notification_example.jpg" width="320" />

To subscribe an anime, long press on the anime in the Recents category of your Library.

<img src="https://github.com/SuperMarcus/NineAnimator/raw/master/Misc/Media/recents_long_press.jpeg" width="320" />

Or simply tap on the subscribe button when you are viewing any anime.

<img src="https://github.com/SuperMarcus/NineAnimator/raw/master/Misc/Media/subscribe_button.jpg" width="320" />

### Smart Home Integration

NineAnimator can be configured to run Home scenes when the playback starts and
ends. The default behavior is to only run the scenes when the video is playing on
external screens (e.g. Google Cast, AirPlay). However, you may change that in the
`Settings` -> `Home` panel.

- NineAnimator runs `Starts Playing` scene immediately after the video starts playing
- The `Ends Playing` scene will be performed 15 seconds before video playback ends

<img src="https://github.com/SuperMarcus/NineAnimator/raw/master/Misc/Media/homekit.jpg" width="320" />

See [`Notifications`](https://github.com/SuperMarcus/NineAnimatorCommon/blob/master/Sources/NineAnimatorCommon/Utilities/Notifications.swift) and
[`HomeController`](https://github.com/SuperMarcus/NineAnimator/blob/master/NineAnimator/Controllers/HomeController.swift) for implementation
details.

### Handoff & Siri Shortcuts

NineAnimator supports Apple's handoff and Siri Shortcuts. This enables you to seamlessly
switch between devices when browsing and viewing anime.

<img src="https://github.com/SuperMarcus/NineAnimator/raw/master/Misc/Media/continuity.jpg" width="320" />

When you browse an anime, depending on the device you are using, the NineAnimator icon
will show up on the dock (iPad) or the task switcher of your other devices. You may tap
on the icon to continue browsing or watching on the new device.

To add a siri shortcut, navigate to the system settings app. Find NineAnimator under
the root menu, tap `Siri & Search`, then tap `Shortcuts`.

### Download Episodes

NineAnimator can download episodes for later playback. Tap on the cloud icon in the anime browser
to initiate download tasks. Downloaded episodes will appear in the Recents tab.

There are some limitations to NineAnimator's ability to download and playback videos:

- NineAnimator only supports downloading videos from a selection of [streaming sources](supported-sources.md)
- Downloaded videos are only available to local playback. You may encounter problems playing offline episodes on AirPlay devices, and, if you are connected to a Google Cast device, NineAnimator will still attempt to fetch online resources for playback.

## Device Compatibility

### iOS/iPadOS Compatibility

NineAnimator is compatible with devices running iOS 13.0 or later. This
includes iPhones and iPads.

The app is tested on the following devices running the latest operating
systems:

- iPhone Xs Max
- iPhone 11
- iPad 9.7-inch (2018)
- iPad Pro 11-inch (2018)

### macOS Compatibility

Starting from version 1.2.6 build 12, NineAnimator releases will include
a macCatalyst binary build. macCatalyst allows you to run NineAnimator
on compatible macOS devices.
