import type { NavbarConfig } from "@vuepress/theme-default";

export const en: NavbarConfig = [
  { text: "Home", link: "/" },
  { text: "FAQ", link: "/help/faq/" },
  {
    text: "Guide",
    children: [
      "/guide/getting-started/",
      "/guide/installation/",
      "/guide/supported-sources/",
      "/guide/third-party-lists/",
      "/guide/backups/",
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
  //   children: ["/tools/backup-viewer"],
  // },
  {
    text: "Contribution",
    children: [
      "/contribution/",
      "/contribution/source-development/",
      "/contribution/runtime/",
      "/contribution/credits/",
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
        ],
      },
    ],
  },
];
