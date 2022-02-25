---
title: Model Reference
lang: en-US
sidebarDepth: 1
---

# Model Reference

Most of the specialized object types have a corresponding wrapper functions.

## FeaturedContainer

The FeaturedContainer object is a simple static featured container struct.

### Required Fields

| Name       | Type                        | Description                                             |
| ---------- | --------------------------- | ------------------------------------------------------- |
| `featured` | \[[AnimeLink](#animelink)\] | The featured anime links                                |
| `latest`   | \[[AnimeLink](#animelink)\] | Links to the latest (last updated) anime on this server |

## BasicFeaturedContainer

The BasicFeaturedContainer object is a simple static featured container struct.

### Required Fields

| Name       | Type                        | Description                                             |
| ---------- | --------------------------- | ------------------------------------------------------- |
| `featured` | \[[AnimeLink](#animelink)\] | The featured anime links                                |
| `latest`   | \[[AnimeLink](#animelink)\] | Links to the latest (last updated) anime on this server |

## Anime

The Anime object represents a collection of information about the `AnimeLink`, the streaming servers and episodes, as well as the references to the tracking contexts of the `AnimeLink`.

### Required Fields

| Name          | Type                                             | Description                                   |
| ------------- | ------------------------------------------------ | --------------------------------------------- |
| `link`        | [AnimeLink](#animelink)                          | The `AnimeLink` struct for all possible links |
| `description` | String                                           | The description of an anime                   |
| `on`          | [Anime.ServerIdentifier: String]                 | The array of servers available of an anime    |
| `episodes`    | [Anime.ServerIdentifier: EpisodeLinksCollection] | The array of lists of episodes                |

### Optional Fields

| Name                   | Type                                                                  | Description                                             |
| ---------------------- | --------------------------------------------------------------------- | ------------------------------------------------------- |
| `alias`                | String                                                                | Another name for the anime                              |
| `additionalAttributes` | [Anime.AttributeKey: Any]                                             | provide additional information for `Anime` struct       |
| `episodesAttributes`   | [[EpisodeLink](#episodelink): Anime.AdditionalEpisodeLinkInformation] | provide additional information for `EpisodeLink` struct |

## AnimeLink

The AnimeLink object is a struct container for all possible links.

### Required Fields

| Name     | Type   | Description                 |
| -------- | ------ | --------------------------- |
| `title`  | String | The title of an anime       |
| `link`   | URL    | The link to the anime       |
| `image`  | URL    | The link to the anime image |
| `source` | Source | The source of the anime     |

## Episode

The Episode object is a struct that wraps information of an anime episode.

### Required Fields

| Name     | Type                        | Description                                 |
| -------- | --------------------------- | ------------------------------------------- |
| `link`   | [EpisodeLink](#episodelink) | The `EpisodeLink` information of an episode |
| `target` | URL                         | The link to the anime episode               |
| `parent` | [Anime](#anime)             | The parent `Anime` struct                   |

### Optional Fields

| Name       | Type          | Description                                                       |
| ---------- | ------------- | ----------------------------------------------------------------- |
| `referer`  | String        | The HTTP referer header to identify where a user is visiting from |
| `userInfo` | [String: Any] | Additional userInfo information                                   |

## EpisodeLink

The EpisodeLink object is a codable stuct that wraps information of an episode for the `Anime`.

### Required Fields

| Name         | Type                    | Description                                |
| ------------ | ----------------------- | ------------------------------------------ |
| `identifier` | Anime.EpisodeIdentifier | An identifier of the episode               |
| `name`       | String                  | The name of the episode                    |
| `server`     | Anime.ServerIdentifier  | The array of servers available of an anime |
| `parent`     | [AnimeLink](#animelink) | The parent `Anime` struct                  |

## AdditionalEpisodeLinkInformation

The AdditionalEpisodeLinkInformation object contains a set of optional information to the `EpisodeLink`. It is attached to the Anime object to provide additional information for `EpisodeLink` struct.

### Required Fields

| Name     | Type                        | Description                     |
| -------- | --------------------------- | ------------------------------- |
| `parent` | [EpisodeLink](#episodelink) | The parent `EpisodeLink` struct |

### Optional Fields

| Name             | Type   | Description                                       |
| ---------------- | ------ | ------------------------------------------------- |
| `synopsis`       | String | An alternate name of the anime episode            |
| `airDate`        | String | The air date of the anime episode                 |
| `season`         | String | The season of when the anime episode was released |
| `episodeNumbers` | Int    | The episode number of the anime episode           |
| `title`          | String | The episode title of the anime episode            |
