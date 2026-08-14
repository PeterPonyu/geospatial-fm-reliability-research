#!/usr/bin/env node
/**
 * Build-time SVG modules from curated extracts. No new science.
 */
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const data = (name) => JSON.parse(readFileSync(join(root, "src/data", name), "utf8"));
const outDir = join(root, "public/figures");
mkdirSync(outDir, { recursive: true });

const enc = data("encoders.json");
const ben = data("bigearthnet.json");
const prior = data("class_prior.json");
const euro = data("eurosat_shift.json");
const colours = enc.palette;

function svg(w, h, body, title) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" role="img" aria-labelledby="t">
<title id="t">${title}</title>
<rect width="100%" height="100%" fill="#fffdf8"/>
${body}
</svg>
`;
}

function xmlText(text) {
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function write(name, content) {
  writeFileSync(join(outDir, name), content);
}

const ink = "#1c1917";
const muted = "#57534e";
const rule = "#d6d3d1";
const source = "#009E73";
const target = "#D55E00";
const nominal = "#44403c";

write(
  "protocol.svg",
  svg(
    1100,
    280,
    `
<text x="24" y="36" font-family="IBM Plex Sans, sans-serif" font-size="14" fill="${muted}">Protocol · freeze encoder → probe → conformal under geographic split → card</text>
${["DATA", "MODEL", "PROBE", "EVAL", "REPORT"]
  .map((lab, i) => {
    const x = 24 + i * 215;
    return `<rect x="${x}" y="56" width="200" height="88" fill="#f7f4ee" stroke="${rule}"/>
<text x="${x + 12}" y="80" font-family="IBM Plex Mono, monospace" font-size="12" fill="${muted}">${i + 1} ${lab}</text>
<text x="${x + 12}" y="108" font-family="IBM Plex Sans, sans-serif" font-size="13" fill="${ink}">${
      ["Optical Sentinel-2 tile", "Frozen optical GFM", "Frozen-embedding probe", "Geographic conformal", "Four-number card"][i]
    }</text>`;
  })
  .join("\n")}
<line x1="550" y1="160" x2="550" y2="188" stroke="${ink}"/>
<rect x="80" y="196" width="420" height="56" fill="#fffdf8" stroke="${target}"/>
<text x="96" y="230" font-family="IBM Plex Sans, sans-serif" font-size="14" fill="${target}">FAILURE — no universal restoration</text>
<rect x="600" y="196" width="420" height="56" fill="#fffdf8" stroke="#0072B2"/>
<text x="616" y="230" font-family="IBM Plex Sans, sans-serif" font-size="14" fill="#0072B2">SURVIVING — conditional labeled-target recalibration</text>
`,
    "Report-card protocol with FAILURE / SURVIVING fork",
  ),
);

write(
  "splitmap.svg",
  svg(
    1100,
    420,
    `
<text x="24" y="32" font-family="IBM Plex Sans, sans-serif" font-size="14" fill="${muted}">Longitude-cut construction · P33 = 4.2°E · source n = 18,090 · target n = 8,910</text>
<rect x="40" y="56" width="1020" height="300" fill="#f7f4ee" stroke="${rule}"/>
<!-- schematic land band -->
<path d="M80,140 C180,90 280,200 420,160 C520,130 620,210 760,150 C880,110 980,180 1040,140 L1040,320 L80,320 Z" fill="#e7e5e4" stroke="${rule}"/>
<!-- target left of cut, source right -->
<rect x="40" y="56" width="470" height="300" fill="${target}" fill-opacity="0.12"/>
<rect x="510" y="56" width="550" height="300" fill="${source}" fill-opacity="0.12"/>
<line x1="510" y1="56" x2="510" y2="356" stroke="${ink}" stroke-width="2"/>
<text x="510" y="48" text-anchor="middle" font-family="IBM Plex Mono, monospace" font-size="12" fill="${ink}">P33 4.2°E</text>
<line x1="250" y1="56" x2="250" y2="356" stroke="${muted}" stroke-dasharray="4 4"/>
<text x="250" y="372" text-anchor="middle" font-family="IBM Plex Mono, monospace" font-size="11" fill="${muted}">P25</text>
<line x1="780" y1="56" x2="780" y2="356" stroke="${muted}" stroke-dasharray="4 4"/>
<text x="780" y="372" text-anchor="middle" font-family="IBM Plex Mono, monospace" font-size="11" fill="${muted}">P50</text>
<text x="180" y="200" font-family="IBM Plex Sans, sans-serif" font-size="16" fill="${target}">target · Iberian–Atlantic</text>
<text x="180" y="224" font-family="IBM Plex Mono, monospace" font-size="14" fill="${ink}">n = 8,910</text>
<text x="640" y="200" font-family="IBM Plex Sans, sans-serif" font-size="16" fill="${source}">source · E/Central</text>
<text x="640" y="224" font-family="IBM Plex Mono, monospace" font-size="14" fill="${ink}">n = 18,090</text>
<text x="24" y="408" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="${muted}">Schematic of the frozen percentile construction. P25/P50 shown as unlabeled percentile guides (degree values not in the frozen table).</text>
`,
    "Schematic East/Central to Iberian-Atlantic longitude cut",
  ),
);

const classes = ["AnnualCrop", "Forest", "PermanentCrop", "Residential", "Highway", "SeaLake"];
const rows = [
  { lab: "source  lon ≥ P33", fill: source },
  { lab: "boundary  |lon − P33| ≤ 1.5°", fill: "#57534e" },
  { lab: "target  lon < P33", fill: target },
];
let tiles = "";
rows.forEach((row, ri) => {
  tiles += `<text x="16" y="${70 + ri * 110}" font-family="IBM Plex Sans, sans-serif" font-size="13" fill="${row.fill}">${xmlText(row.lab)}</text>`;
  classes.forEach((c, ci) => {
    const x = 220 + ci * 140;
    const y = 40 + ri * 110;
    tiles += `<rect x="${x}" y="${y}" width="120" height="88" fill="#f7f4ee" stroke="${row.fill}"/>
<text x="${x + 8}" y="${y + 28}" font-family="IBM Plex Sans, sans-serif" font-size="11" fill="${ink}">${c}</text>
<text x="${x + 8}" y="${y + 48}" font-family="IBM Plex Mono, monospace" font-size="10" fill="${muted}">schematic tile</text>
<text x="${x + 8}" y="${y + 68}" font-family="IBM Plex Mono, monospace" font-size="10" fill="${muted}">schematic cell</text>`;
  });
});
write(
  "geopatches.svg",
  svg(
    1100,
    380,
    `<text x="16" y="24" font-family="IBM Plex Sans, sans-serif" font-size="14" fill="${muted}">Patch construction (six classes × source / boundary / target) at the P33 longitude cut. Schematic labeled grid.</text>${tiles}`,
    "Geographic patch-strip construction",
  ),
);

function barChart(title, items, yMax, yLabel) {
  const w = 1100;
  const h = 360;
  const left = 72;
  const bottom = 300;
  const top = 48;
  const bw = 800 / items.length;
  const bars = items
    .map((it, i) => {
      const bh = ((it.v / yMax) * (bottom - top));
      const x = left + i * bw + 8;
      const y = bottom - bh;
      return `<rect x="${x}" y="${y}" width="${bw - 16}" height="${bh}" fill="${it.c}"/>
<text x="${x + (bw - 16) / 2}" y="${bottom + 18}" text-anchor="middle" font-family="IBM Plex Sans, sans-serif" font-size="11" fill="${ink}">${it.l}</text>
<text x="${x + (bw - 16) / 2}" y="${y - 6}" text-anchor="middle" font-family="IBM Plex Mono, monospace" font-size="11" fill="${ink}">${it.v}</text>`;
    })
    .join("\n");
  return svg(
    w,
    h,
    `<text x="24" y="28" font-family="IBM Plex Sans, sans-serif" font-size="14" fill="${muted}">${title}</text>
<line x1="${left}" y1="${bottom}" x2="1000" y2="${bottom}" stroke="${rule}"/>
<line x1="${left}" y1="${top}" x2="${left}" y2="${bottom}" stroke="${rule}"/>
<text x="24" y="180" transform="rotate(-90 24 180)" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="${muted}">${yLabel}</text>
${bars}`,
    title,
  );
}

write(
  "classprior.svg",
  barChart(
    "Target/source class-prior ratio at P33 (five extreme classes)",
    prior.rows.map((r) => ({
      l: r.class.split(" ")[0],
      v: r.ratio,
      c: r.direction === "enriched" ? target : source,
    })),
    7,
    "target/source",
  ),
);

const crc05 = ben.crc.filter((r) => r.alpha === 0.05);
let crcBars = "";
crc05.forEach((r, i) => {
  const x0 = 90 + i * 200;
  const cols = [
    { v: Number(r.fnr_in), c: "#0072B2", lab: "in-dist" },
    { v: Number(r.fnr_shift), c: target, lab: "shift" },
    { v: Number(r.fnr_mond), c: source, lab: "Mondrian" },
  ];
  cols.forEach((col, j) => {
    const bh = col.v * 900;
    crcBars += `<rect x="${x0 + j * 28}" y="${280 - bh}" width="24" height="${bh}" fill="${col.c}"/>`;
  });
  crcBars += `<text x="${x0 + 36}" y="304" text-anchor="middle" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="${ink}">${r.encoder.replace("SSL4EO-", "")}</text>`;
});
write(
  "crc_fnr.svg",
  svg(
    1100,
    340,
    `<text x="24" y="28" font-family="IBM Plex Sans, sans-serif" font-size="14" fill="${muted}">CRC FNR at α = 0.05 · in-distribution / shift / Mondrian-CRC repair · dashed = α</text>
<line x1="70" y1="${280 - 0.05 * 900}" x2="1060" y2="${280 - 0.05 * 900}" stroke="${nominal}" stroke-dasharray="5 4"/>
${crcBars}
<rect x="820" y="48" width="12" height="12" fill="#0072B2"/><text x="838" y="58" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="${ink}">in-dist</text>
<rect x="900" y="48" width="12" height="12" fill="${target}"/><text x="918" y="58" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="${ink}">shift</text>
<rect x="980" y="48" width="12" height="12" fill="${source}"/><text x="998" y="58" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="${ink}">Mondrian</text>
<text x="24" y="328" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="${muted}">Every encoder meets the in-distribution FNR; every encoder incurs debt under shift; Mondrian-CRC restores it.</text>`,
    "CRC FNR in-distribution, shift, and Mondrian repair",
  ),
);

let scatter = "";
ben.fnr_decouple_alpha05.forEach((r) => {
  const x = 80 + (r.map_in - 0.42) * 2800;
  const y = 300 - (r.fnr_shift - 0.12) * 1400;
  const col = colours[r.encoder] || (r.original5 ? "#0072B2" : "#57534e");
  if (r.original5) {
    scatter += `<circle cx="${x}" cy="${y}" r="7" fill="${col}" stroke="${ink}"/>`;
  } else {
    scatter += `<polygon points="${x},${y - 8} ${x + 7},${y + 6} ${x - 7},${y + 6}" fill="none" stroke="${col}" stroke-width="1.6"/>`;
  }
});
write(
  "inversion_n13.svg",
  svg(
    720,
    360,
    `<text x="24" y="28" font-family="IBM Plex Sans, sans-serif" font-size="14" fill="${muted}">BigEarthNet α = 0.05 · FNR under shift vs in-distribution mAP · Spearman ρ = +0.32 (p = 0.28)</text>
<line x1="80" y1="300" x2="680" y2="300" stroke="${rule}"/>
<line x1="80" y1="48" x2="80" y2="300" stroke="${rule}"/>
<text x="380" y="332" text-anchor="middle" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="${muted}">mAP (in-distribution)</text>
<text x="20" y="180" transform="rotate(-90 20 180)" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="${muted}">FNR under shift</text>
${scatter}
<circle cx="500" cy="48" r="5" fill="#0072B2" stroke="${ink}"/><text x="512" y="52" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="${ink}">original five</text>
<polygon points="620,42 627,56 613,56" fill="none" stroke="#57534e"/><text x="634" y="52" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="${ink}">added eight</text>
<text x="24" y="352" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="${muted}">The five-encoder inversion (ρ = +0.90) regresses toward zero at n = 13. No trend line: the correlation is not significant.</text>`,
    "Accuracy–FNR scatter for thirteen encoders",
  ),
);

const cond = euro.condcov_alpha05;
write(
  "condcov.svg",
  barChart(
    "EuroSAT worst-class gap after marginal repair (α = 0.05). SSL4EO-DINO is the load-bearing datum.",
    cond.map((r) => ({
      l: r.encoder.replace("SSL4EO-", ""),
      v: r.gap,
      c: r.encoder === "SSL4EO-DINO" ? target : colours[r.encoder] || ink,
    })),
    0.12,
    "G_worst",
  ),
);

write(
  "setsize.svg",
  barChart(
    "EuroSAT spatial-Mondrian mean set size at α = 0.05 (singleton floor = 1)",
    Object.entries(euro.mondrian_setsize_alpha05).map(([k, v]) => ({
      l: k.replace("SSL4EO-", ""),
      v,
      c: colours[k] || ink,
    })),
    2,
    "set size",
  ),
);

const plan = euro.planning_endpoints.filter((r) => r.alpha === 0.1);
let planLines = "";
plan.forEach((r) => {
  const c = colours[r.encoder] || ink;
  const x1 = 120;
  const x2 = 520;
  const y1 = 280 - (r.cov_005 - 0.85) * 1200;
  const y2 = 280 - (r.cov_030 - 0.85) * 1200;
  planLines += `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${c}" stroke-width="1.6"/>
<circle cx="${x1}" cy="${y1}" r="4" fill="${c}"/>
<circle cx="${x2}" cy="${y2}" r="4" fill="${c}"/>`;
});
write(
  "planning.svg",
  svg(
    720,
    340,
    `<text x="24" y="28" font-family="IBM Plex Sans, sans-serif" font-size="14" fill="${muted}">EuroSAT target-calibrated coverage endpoints at α = 0.10 (0.5% → 30% labeled slice)</text>
<line x1="120" y1="280" x2="560" y2="280" stroke="${rule}"/>
<line x1="120" y1="${280 - (0.9 - 0.85) * 1200}" x2="560" y2="${280 - (0.9 - 0.85) * 1200}" stroke="${nominal}" stroke-dasharray="5 4"/>
${planLines}
<text x="120" y="300" text-anchor="middle" font-family="IBM Plex Mono, monospace" font-size="11" fill="${muted}">0.5% (n = 44)</text>
<text x="520" y="300" text-anchor="middle" font-family="IBM Plex Mono, monospace" font-size="11" fill="${muted}">30% (n = 2,673)</text>
<text x="24" y="328" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="${muted}">Only frozen endpoints are drawn. Intermediate budgets are not tabulated here. Coverage starts conservative and tightens toward nominal.</text>`,
    "Planning-curve endpoints for labeled target budget",
  ),
);

const split = euro.split_coverage_alpha05;
const mond = euro.mondrian_coverage_alpha05;
let covBars = "";
Object.keys(split).forEach((k, i) => {
  const x = 80 + i * 200;
  const s = split[k];
  const m = mond[k];
  covBars += `<rect x="${x}" y="${280 - s * 220}" width="36" height="${s * 220}" fill="${target}"/>
<rect x="${x + 44}" y="${280 - m * 220}" width="36" height="${m * 220}" fill="${source}"/>
<text x="${x + 40}" y="304" text-anchor="middle" font-family="IBM Plex Sans, sans-serif" font-size="11" fill="${ink}">${k.replace("SSL4EO-", "")}</text>`;
});
write(
  "coverage_restore.svg",
  svg(
    1100,
    340,
    `<text x="24" y="28" font-family="IBM Plex Sans, sans-serif" font-size="14" fill="${muted}">EuroSAT α = 0.05 coverage · source split vs spatial-Mondrian · dashed = 1 − α = 0.95</text>
<line x1="60" y1="${280 - 0.95 * 220}" x2="1060" y2="${280 - 0.95 * 220}" stroke="${nominal}" stroke-dasharray="5 4"/>
${covBars}
<rect x="820" y="48" width="12" height="12" fill="${target}"/><text x="838" y="58" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="${ink}">split (source)</text>
<rect x="960" y="48" width="12" height="12" fill="${source}"/><text x="978" y="58" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="${ink}">spatial-Mondrian</text>`,
    "Coverage restoration under labeled target calibration",
  ),
);

const debtOrder = ["Prithvi", "DOFA", "SSL4EO-DINO", "SSL4EO-MAE", "Clay"];
const debt = euro.integrated_debt_e3;
const acc = euro.accuracy_in_to_shift;
const ece = euro.ece_shift;
let f1 = "";
debtOrder.forEach((k, i) => {
  const x = 40 + i * 210;
  const c = colours[k] || ink;
  const d = debt[k];
  const a = acc[k];
  const e = ece[k];
  const cov = euro.split_coverage_alpha05[k];
  f1 += `<text x="${x}" y="36" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="${c}">${k.replace("SSL4EO-", "")}</text>`;
  f1 += `<text x="${x}" y="70" font-family="IBM Plex Mono, monospace" font-size="12" fill="${ink}">debt ${d}</text>`;
  if (a) f1 += `<text x="${x}" y="130" font-family="IBM Plex Mono, monospace" font-size="12" fill="${ink}">acc ${a.in}→${a.shift}</text>`;
  if (e != null) f1 += `<text x="${x}" y="190" font-family="IBM Plex Mono, monospace" font-size="12" fill="${ink}">ECE ${e}</text>`;
  f1 += `<text x="${x}" y="250" font-family="IBM Plex Mono, monospace" font-size="12" fill="${ink}">split ${cov}</text>`;
});
write(
  "debt_robust.svg",
  svg(
    1100,
    300,
    `<text x="24" y="20" font-family="IBM Plex Sans, sans-serif" font-size="14" fill="${muted}">EuroSAT geographic debt order (integrated) · accuracy drop · shift ECE · split coverage at α = 0.05. Accuracy is not the reliability ranking.</text>
${f1}
<text x="24" y="288" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="${muted}">A: integrated debt (×10⁻³). B: in-distribution → shift accuracy (where tabulated). C: shift ECE. D: split coverage. Encoder hues locked.</text>`,
    "Accuracy is not the reliability ranking",
  ),
);

const sing = euro.singleton_prithvi_alpha05;
let singPts = "";
sing.forEach((r) => {
  const x = 80 + Math.log10(r.n) * 140;
  const y = 280 - r.acc * 240;
  singPts += `<circle cx="${x}" cy="${y}" r="4" fill="${colours.Prithvi}"/>`;
});
write(
  "singleton.svg",
  svg(
    720,
    340,
    `<text x="24" y="28" font-family="IBM Plex Sans, sans-serif" font-size="14" fill="${muted}">Prithvi singleton / low-shot boundary at α = 0.05 (log n). The audit is informative only while sets are non-degenerate.</text>
<line x1="80" y1="280" x2="680" y2="280" stroke="${rule}"/>
<line x1="80" y1="40" x2="80" y2="280" stroke="${rule}"/>
${singPts}
<text x="80" y="300" font-family="IBM Plex Mono, monospace" font-size="11" fill="${muted}">n = 108</text>
<text x="560" y="300" font-family="IBM Plex Mono, monospace" font-size="11" fill="${muted}">n = 10,854</text>
<text x="24" y="328" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="${muted}">Accuracy falls and set size leaves the singleton floor as the labeled slice shrinks.</text>`,
    "Singleton and low-shot boundary for Prithvi",
  ),
);

write(
  "glyph.svg",
  `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" role="img" aria-label="Longitude-cut glyph">
<rect width="24" height="24" fill="none"/>
<rect x="2" y="4" width="9" height="16" fill="${target}"/>
<rect x="13" y="4" width="9" height="16" fill="${source}"/>
<line x1="12" y1="2" x2="12" y2="22" stroke="${ink}" stroke-width="1.5"/>
</svg>
`,
);

console.log("plot_build: wrote SVG modules to public/figures");

function assertSvgWellFormed(path) {
  const text = readFileSync(path, "utf8");
  const textNodes = [...text.matchAll(/<text\b[^>]*>(.*?)<\/text>/gs)].map((match) => match[1]);
  for (const node of textNodes) {
    if (/<|&(?!amp;|lt;|gt;)/.test(node)) {
      throw new Error(`plot_build: unescaped text in ${path}: ${node}`);
    }
  }
}

for (const name of [
  "protocol.svg",
  "splitmap.svg",
  "geopatches.svg",
  "classprior.svg",
  "crc_fnr.svg",
  "inversion_n13.svg",
  "condcov.svg",
  "setsize.svg",
  "planning.svg",
  "coverage_restore.svg",
  "debt_robust.svg",
  "singleton.svg",
  "glyph.svg",
]) {
  assertSvgWellFormed(join(outDir, name));
}
console.log("plot_build: SVG modules pass XML text checks");
