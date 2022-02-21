import type { SidebarConfig } from "@vuepress/theme-default";

export const en: SidebarConfig = {
  "/FAQ/": [{ text: "FAQ", link: "/help/faq/README/md" }],
  "/guide/": [
    {
      text: "Guide",
      children: ["/guide/getting-started.md"],
    },
  ],
  "/tools/": [
    {
      text: "Tools",
      children: ["/tools/backup-viewer"],
    },
  ],
  "/contribution/": [
    {
      text: "Contribution",
      children: [
        "/contribution/source-development.md",
        "/contribution/source-development/quickstart.md",
      ],
    },
  ],
};
