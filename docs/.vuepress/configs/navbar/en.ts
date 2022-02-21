import type { NavbarConfig } from "@vuepress/theme-default";

export const en: NavbarConfig = [
  { text: "Home", link: "/" },
  { text: "FAQ", link: "/help/faq/" },
  {
    text: "Guide",
    children: [
      {
        text: "Getting started",
        link: "/guide/getting-started/",
      },
      // Reserved for NACore
      // {
      //   text: "External Source",
      //   link: "/guide/external-source/",
      // },
    ],
  },
  {
    text: "Tools",
    children: [
      {
        text: "Backup Viewer",
        link: "/tools/backup-viewer/",
      },
    ],
  },
  {
    text: "Contribution",
    children: [
      {
        text: "Contribute to NineAnimator",
        link: "/contribution/",
      },
      {
        text: "Source Development",
        link: "/contribution/source-development/",
      },
    ],
  },
  {
    text: "Links",
    children: [
      {
        text: "Community",
        children: [
          { text: "Discord", link: "https://discord.gg/dzTVzeW" },
          { text: "Reddit", link: "https://www.reddit.com/r/NineAnimator/" },
          {
            text: "GitHub",
            link: "https://github.com/SuperMarcus/NineAnimator",
          },
          {
            text: "Website",
            link: "https://nineanimator.marcuszhou.com/",
          },
        ],
      },
    ],
  },
];
