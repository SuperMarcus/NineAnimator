---
title: Backups
lang: en-US
---

# Backup History & Subscriptions

> Some updates of NineAnimator or improper operations may cause the anime under
> the Recents tab to disappear. Thus it is always a good habit to regularly backup
> the playback histories and progresses.

NineAnimator can export the recently watched anime list and the playback histories to
a `.naconfig` file. You may use this file to restore anime to the Recents tab or sync
progresses between devices.

### Creating Backups

Navigate to the settings menu and tap on the `Export History` button. NineAnimator
will create a backup file with the following contents:

- Anime subscriptions;
- Recently browsed titles;
- Episode playback progresses.

### Restoring Backups

There are three ways to import a `.naconfig` file. When you open a `.naconfig`
file, NineAnimator will prompt you to choose one.

- `Replace Current`: Choosing this option will replace all local playback histories and progresses with the ones contained in the `.naconfig` file.
- `Merge - Prioritize Local`: Choosing this option will merge the histories stored in the `.naconfig` file with local history. Local histories will be showed on top in the Recents tab. NineAnimator will prefer the local version of any data if it is present in both the importing `.naconfig` file and the local database.
- `Merge - Prioritize Importing`: Choosing this option will merge the histories stored in the `.naconfig` file with local history. The importing histories will be showed on top in the Recents tab. NineAnimator will prefer the importing version of any data if it is present in both the importing `.naconfig` file and the local database.

### `.naconfig` File

The `.naconfig` is essentially a binary, property list encoded dictionary with three
entries:

- `history`: A list of serialized `AnimeLink` objects from the recently watched tab.
- `progresses`: A dictionary keyed by the episode identifier for the persisted playback progresses.
- `exportedDate`: The `Date` that this file is generated.
- `trackingData`: A dictionary keyed by `AnimeLink` for the serialized `TrackingContext`.
- `subscriptions`: A list of serialized `AnimeLink` for your subscribed anime.

See [StatesSerialization.swift](https://github.com/SuperMarcus/NineAnimator/blob/master/NineAnimator/Utilities/StatesSerialization.swift) for implementation details.
