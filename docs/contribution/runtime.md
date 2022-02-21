---
title: Runtime Configurations
lang: en-US
---

# Runtime Configurations

> Note: Runtime configurations are designed for developing, testing, and debugging purposes. You shouldn't
> need to change anything mentioned in this page in order for NineAnimator to run.

It's possible to tweak some of NineAnimator's behaviors through changing environment
variables. This is particularly useful for unit testing and debugging purposes.

### Environment Variables

|            Variable Name            | Description                                                                                                                                                        |
| :---------------------------------: | :----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|    `NINEANIMATOR_NO_SETUP_SCENE`    | Set this variable to prevent NineAnimator from displaying the welcome screen at launch.                                                                            |
|    `NINEANIMATOR_NO_ANIMATIONS`     | Set this variable to disable `UIView` animations in NineAnimator.                                                                                                  |
| `NINEANIMATOR_APPEARANCE_OVERRIDE`  | Set this variable to force NineAnimator to switch to a specific appearance at launch. The user's configuration will not be changed.                                |
| `NINEANIMATOR_CREATE_DUMMY_RECORDS` | Set this variable to create a list of dummy recent anime and playback records at launch (DEBUG builds only). The dummy records are appended to the user's records. |
