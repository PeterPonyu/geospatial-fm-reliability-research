import { defineConfig } from "astro/config";

export default defineConfig({
  site: "https://peterponyu.github.io",
  base: "/geospatial-fm-reliability-research",
  trailingSlash: "always",
  build: {
    format: "directory",
  },
});
