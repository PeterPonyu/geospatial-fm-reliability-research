#!/usr/bin/env node
import { readdirSync, readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { dirname } from "node:path";

const dist = join(dirname(fileURLToPath(import.meta.url)), "..", "dist");
if (!existsSync(dist)) {
  console.error("leak-scan: dist/ missing");
  process.exit(1);
}

const patterns = [
  { name: "email", re: /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i },
  { name: "home-path", re: /\/home\/[A-Za-z0-9._-]+/ },
  { name: "experiment-dump", re: /experiments\/results/ },
  { name: "json-filename", re: /\b[\w.-]+\.json\b/ },
  { name: "tex-ref", re: /\\(cite|ref)\{/ },
  { name: "manuscript-path", re: /manuscripts\// },
  { name: "checkpoint", re: /checkpoint[_-]?id/i },
  { name: "autodl", re: /autodl/i },
  { name: "launch-cta", re: /Launch\s*→/ },
  { name: "rotcert", re: /RotCert|oriented bounding/i },
  { name: "matbench", re: /Matbench/ },
  { name: "mvtec", re: /MVTec/ },
  { name: "jcp-oxide", re: /\bJCP\b|oxide DAF/ },
  { name: "asr-gate", re: /asr-gate/ },
  { name: "paper-pdf", re: /paper_isprs\.pdf|paper_.*\.pdf/ },
];

function walk(dir, acc = []) {
  for (const ent of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, ent.name);
    if (ent.isDirectory()) walk(p, acc);
    else if (ent.name.endsWith(".html") || ent.name.endsWith(".svg")) acc.push(p);
  }
  return acc;
}

const files = walk(dist);
let hits = 0;
for (const file of files) {
  const text = readFileSync(file, "utf8");
  for (const { name, re } of patterns) {
    const m = text.match(re);
    if (m) {
      console.error(`leak-scan FAIL ${name} in ${file}: ${m[0]}`);
      hits += 1;
    }
  }
}
if (hits) {
  process.exit(1);
}
console.log(`leak-scan: OK (${files.length} html/svg files)`);
