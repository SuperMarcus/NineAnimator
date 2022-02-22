import { defineClientAppEnhance } from "@vuepress/client";
import VueLazyLoad from "vue3-lazyload";

export default defineClientAppEnhance(({ app, router, siteData }) => {
  app.use(VueLazyLoad);
});
