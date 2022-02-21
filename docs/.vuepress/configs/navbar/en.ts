import type { NavbarConfig } from "@vuepress/theme-default";

export const en: NavbarConfig = [
  { text: "Home", link: "/" },
  { text: "FAQ", link: "/help/faq/" },
  {
    text: "Guide",
    children: [
      {
        text: "Getting Started",
        link: "/guide/getting-started/",
      },
      {
        text: "Installation",
        link: "/guide/installation/",
      },
      {
        text: "Supported Sources",
        link: "/guide/supported-sources/",
      },
      {
        text: "Third Party Lists",
        link: "/guide/third-party-lists/",
      },
      {
        text: "Backups",
        link: "/guide/backups/",
      },
      // Reserved for NACore
      // {
      //   text: "External Source",
      //   link: "/guide/external-source/",
      // },
    ],
  },
  // Disable for now
  // {
  //   text: "Tools",
  //   children: [
  //     {
  //       text: "Backup Viewer",
  //       link: "/tools/backup-viewer/",
  //     },
  //   ],
  // },
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
      {
        text: "Credits",
        link: "/contribution/credits/",
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
