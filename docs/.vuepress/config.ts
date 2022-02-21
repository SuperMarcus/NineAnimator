import { defineUserConfig } from "@vuepress/cli";
import type { DefaultThemeOptions } from "@vuepress/theme-default";
import { path } from "@vuepress/utils";
import { navbar, sidebar } from "./configs";

const isProd = process.env.NODE_ENV === "production";

const config = defineUserConfig<DefaultThemeOptions>({
  base: "/NineAnimator-website/",

  // prettier-ignore
  head: [
    ["link", { rel: "icon", type:"image/png", sizes:"16x16", href:`/images/icons/favicon-16x16.png` }],
    ["link", { rel: "icon", type:"image/png", sizes:"32x32", href:`/images/icons/favicon-32x32.png` }],
    ["link", { rel: "manifest", href:"/manifest.webmanifest"}],
    ["link", { rel: "apple-touch-icon", href:`/images/icons/apple-touch-icon.png`}, ],
    ["link", {rel:"mask-icon", href:"/images/icons/safari-pinned-tab.svg", color:"#8e5af7" }],
    ["meta", {name:"application-name", content:"NineAnimator" }],
    ["meta", { name: "apple-mobile-web-app-title", content:"NineAnimator"}],
    ["meta", {name:"apple-mobile-web-app-status-bar-style", content:"black" }],
    ["meta", { name: "msapplication-TileColor", content:"#8e5af7"}],
    ["meta", { name: "theme-color", content:"#8e5af7"}],
  ],

  // site-level locales config
  locales: {
    "/": {
      lang: "en-US",
      title: "NineAnimator",
      description:
        "NineAnimator is a free and open source anime watching app for iOS and macOS",
    },
  },

  bundler:
    // specify bundler via environment variable
    process.env.DOCS_BUNDLER ??
    // use vite by default
    "@vuepress/vite",

  themeConfig: {
    logo: "/images/logo.png",
    repo: "SuperMarcus/NineAnimator",
    docsDir: "docs",

    // theme-level locales config
    locales: {
      /**
       * English locale config
       *
       * As the default locale of @vuepress/theme-default is English,
       * we don't need to set all of the locale fields
       */
      "/": {
        // navbar
        navbar: navbar.en,

        // sidebar
        sidebar: sidebar.en,

        // page meta
        editLinkText: "Edit this page on GitHub",
      },
    },

    themePlugins: {
      // only enable git plugin in production mode
      git: isProd,
      // // use shiki plugin in production mode instead
      prismjs: !isProd,
    },
  },

  plugins: [
    [
      "@vuepress/plugin-search",
      {
        // exclude the homepage
        isSearchable: (page) => page.path !== "/",
      },
    ],
    [
      "@vuepress/plugin-register-components",
      {
        componentsDir: path.resolve(__dirname, "./components"),
      },
    ],
    // only enable shiki plugin in production mode
    [
      "@vuepress/plugin-shiki",
      isProd
        ? {
            theme: "dark-plus",
          }
        : false,
    ],
    [
      "@vuepress/pwa",
      {
        skipWaiting: true,
      },
    ],
  ],
});

export default config;
