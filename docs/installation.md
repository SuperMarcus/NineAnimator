## Installation

To install NineAnimator, you have the following options:

- TestFlight Beta Testing
- Install from Third-Party App Stores
- Install via Cydia Impactor with Compiled IPAs
- Build from Source Code

## TestFlight Beta Testing

NineAnimator is now available via TestFlight. Join the [NineAnimator Beta Testing Program](https://testflight.apple.com/join/SzIVhF6w).

## Third-Party App Stores

NineAnimator is available on the following third-party app stores:

- [Ignition](//app.ignition.fun)
- [Build Store](//builds.io)

## Cydia Impactor

Download the latest compiled IPA file from the [release page](https://github.com/SuperMarcus/NineAnimator/releases/latest)
and install the app with Cydia Impactor.

For detailed instructions please view the **#installation** channel on our Discord server.

## Build from Source Code

#### Step One: Install Carthage

To build this app, you will need [Carthage](https://github.com/Carthage/Carthage#installing-carthage) installed.

The simplest way to install Carthage is to use Homebrew.

```sh
$ brew update
$ brew install carthage
```

You can also install Carthage with the installer package, which can be found
[here](https://github.com/Carthage/Carthage/releases).

#### Step Two: Build the app with Xcode

You won't need any Apple Developer membership to build and install this app.
Open this project in Xcode, connect your phone to the computer, select your
device, and click the run button on the top left corner.

![Xcode select device](../Misc/Media/xcode_select_device.jpg)

Xcode might prompt you that the bundle identifier cannot be used. In this case,
select the `NineAnimator` in the Navigator, choose `NineAnimator` in the Targets,
click the `General` tab on the top, and change the `Bundle Identifier` in the
Identity section to whatever you like. Then, click the `Team` drawer in the Signing
section, and choose your developer profile. You should be good to go after this.

#### Step Three (Optional): Update dependencies

All the required binaries have been compiled and uploaded to the repository, so
you shouldn't need to do this. But if something doesn't work out, you might want
to try updating the dependencies.

Still, you should make sure that you have a working copy of Carthage first.

```sh
$ carthage update
```
