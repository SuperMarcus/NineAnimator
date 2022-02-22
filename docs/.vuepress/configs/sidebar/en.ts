import type { SidebarConfig } from "@vuepress/theme-default";

export const en: SidebarConfig = {
  "/FAQ/": [{ text: "FAQ", link: "/help/faq/README.md" }],
  "/guide/": [
    {
      text: "Guide",
      children: [
        "/guide/getting-started/",
        "/guide/installation/",
        "/guide/supported-sources/",
        "/guide/third-party-lists/",
        "/guide/backups/",
      ],
    },
  ],
  // Disable for now
  // "/tools/": [
  //   {
  //     text: "Tools",
  //     children: ["/tools/backup-viewer"],
  //   },
  // ],
  "/contribution/": [
    {
      text: "Contribution",
      children: [
        "/contribution/",
        "/contribution/source-development/",
        "/contribution/runtime/",
        "/contribution/credits/",
      ],
    },
  ],
  "/contribution/source-development/": [
    {
      text: "Source Development",
      children: [
        "/contribution/source-development/",
        "/contribution/source-development/quickstart",
        "/contribution/source-development/parsing-guide",
        "/contribution/source-development/function-definitions",
      ],
    },
  ],
};
