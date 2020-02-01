## Runtime Configurations

It's possible to tweak some of NineAnimator's behaviors through changing environment
variables. This is particularly useful for unit testing and debugging purposes.

### Environment Variables

| Variable Name                                               | Default Value | Description |
| :------------------------------------------------: | :--------------: | :------------: |
| `NINEANIMATOR_NO_SETUP_SCENE`             | undefined      | Set this variable to prevent NineAnimator from displaying the welcome screen at launch. |
| `NINEANIMATOR_NO_ANIMATIONS`               | undefined      | Set this variable to disable `UIView` animations
in NineAnimator. |
| `NINEANIMATOR_APPEARANCE_OVERRIDE`   | undefined      | Set this variable to force NineAnimator to switch to a specific appearance at launch. The user's configuration will not be changed. |
| `NINEANIMATOR_CREATE_DUMMY_RECORDS` | undefined      | Set this variable to create a list of dummy recent anime and playback records at launch (DEBUG builds only). The dummy records are appended to the user's records.  |
