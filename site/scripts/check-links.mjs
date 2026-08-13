#!/usr/bin/env node
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const dist = join(root, "dist");
const prefix = "/geospatial-fm-reliability-research/";
const routes = ["", "geography/", "debt/", "repair/", "roster/", "honesty/", "cite/"];

if (!existsSync(dist)) {
  console.error("check-links: dist/ missing");
  process.exit(1);
}

let fail = 0;
for (const r of routes) {
  const p = join(dist, r, "index.html");
  if (!existsSync(p)) {
    console.error("missing route", r || "/");
    fail += 1;
  }
}
if (!existsSync(join(dist, "404.html"))) {
  console.error("missing 404.html");
  fail += 1;
}

function walk(dir, acc = []) {
  for (const ent of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, ent.name);
    if (ent.isDirectory()) walk(p, acc);
    else if (ent.name.endsWith(".html")) acc.push(p);
  }
  return acc;
}

const hrefRe = /href="([^"]+)"/g;
for (const file of walk(dist)) {
  const html = readFileSync(file, "utf8");
  if (html.includes('href="/css/') || html.includes('src="/assets/')) {
    console.error("unprefixed root asset in", file);
    fail += 1;
  }
  let m;
  while ((m = hrefRe.exec(html))) {
    const href = m[1];
    if (href.startsWith("http") || href.startsWith("mailto:") || href.startsWith("#")) continue;
    if (href.startsWith("/") && !href.startsWith(prefix) && !href.startsWith("/geospatial-fm-reliability-research")) {
      console.error("href missing pathPrefix", href, "in", file);
      fail += 1;
    }
  }
}

if (fail) process.exit(1);
console.log("check-links: OK");
