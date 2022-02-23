---
title: Backup Viewer
lang: en-US
pageClass: backup-viewer-page
---

# NineAnimator Backup Viewer (WIP)

::: tip How do I use the Backup Viewer?

NineAnimator uses a properity format `.naconfig` for backing up of your libraries.
The `.naconfig` is essentially a binary, property list encoded dictionary with three
entries:

- `history`: A list of serialized `AnimeLink` objects from the recently watched tab.
- `progresses`: A dictionary keyed by the episode identifier for the persisted playback progresses.
- `exportedDate`: The `Date` that this file is generated.
- `trackingData`: A dictionary keyed by `AnimeLink` for the serialized `TrackingContext`.
- `subscriptions`: A list of serialized `AnimeLink` for your subscribed anime.

To view your library:

1. [Export a backup](/guide/backups.html#creating-backups) of your library
2. [Restore](/guide/backups.html#restoring-backups) the edited version of your library (optional)

<aside>Please note that the viewer can take some time on <b>large</b> libraries.</aside>
<br/>
:::

<br/>
<br/>

<BackupViewer/>

<style scoped>
.custom-block.aside
{
    text-align: left;
}
</style>
