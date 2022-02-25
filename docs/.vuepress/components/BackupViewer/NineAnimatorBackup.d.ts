export interface NineAnimatorBackup {
  exportedDate: string | Date;
  progresses: { [key: string]: number };
  trackingData: TrackingDatum[] | Uint8Array;
  subscriptions: AnimeLink[];
  history: AnimeLink[];
}

export interface AnimeLink {
  title: string;
  source: string;
  image: Link;
  link: Link;
}

export interface TrackingDatum {
  title?: string;
  source?: string;
  image?: Link;
  link?: Link;
  data?: number[];
}

export interface Link {
  relative: string;
}
