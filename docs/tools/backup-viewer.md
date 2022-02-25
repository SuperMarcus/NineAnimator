---
title: Backup Viewer
lang: en-US
sidebar: false
pageClass: backup-viewer-page
---

# NineAnimator Backup Viewer

::: tip How do I use the Backup Viewer?

NineAnimator uses a propriety format `.naconfig` for backing up of your libraries.
The `.naconfig` is essentially a binary, property list encoded dictionary with three
entries:

- `history`: A list of serialized `AnimeLink` objects from the recently watched tab.
- `progresses`: A dictionary keyed by the episode identifier for the persisted playback progresses.
- `exportedDate`: The `Date` that this file is generated.
- `trackingData`: A dictionary keyed by `AnimeLink` for the serialized `TrackingContext`.
- `subscriptions`: A list of serialized `AnimeLink` for your subscribed anime.

Note: Only `history` and `subscriptions` will be available for viewing. The process is done client-side, your backup data is not sent to any servers.

To view your library:

1. [Export a backup](/guide/backups.html#creating-backups) of your library
2. [Restore](/guide/backups.html#restoring-backups) the edited version of your library (optional)

<aside>Please note that the viewer can take some time on <b>large</b> libraries.</aside>
<br/>
:::

<br/>
<br/>

<BackupViewer/>
