import { defineClientAppEnhance } from "@vuepress/client";
import VueLazyLoad from "vue3-lazyload";
import Notifications from "@kyvg/vue3-notification";

export default defineClientAppEnhance(({ app, router, siteData }) => {
  app.use(VueLazyLoad);
  app.use(Notifications);
});
