#!/usr/bin/env node
// scripts/macos/patch-camoufox-fonts.mjs
//
// Camoufox sets `font.system.whitelist` from camoufox-js's
// `mappings/fonts.config.js` `win` array (when CAMOFOX_OS=windows).
// On macOS the Camoufox browser binary cannot render any of the Windows
// fonts in that whitelist, so CSS that names them falls through to a
// renderer fallback that does not include CJK glyphs and Japanese /
// Korean / Chinese text renders as 文字化け.
//
// camofox-browser does not expose a way to pass extra fonts to camoufox-js,
// so the whitelist cannot be extended from the outside. This script patches
// camoufox-js in place: it inserts the common macOS CJK family names
// (Hiragino, PingFang, AppleGothic, ...) into the `win` array so the
// runtime-applied whitelist allows the renderer to use them.
//
// The patch is idempotent (marker-guarded) and tolerates being re-run after
// `npm install`. Run after every install:
//
//     node ~/camofox-mcp/scripts/macos/patch-camoufox-fonts.mjs

import fs from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
const cliPath = args.find((a) => !a.startsWith("-"));
const candidates = [
    cliPath,
    process.env.CAMOFOX_BROWSER_PKG_ROOT
        && path.join(process.env.CAMOFOX_BROWSER_PKG_ROOT, "node_modules/camoufox-js/dist/mappings/fonts.config.js"),
    path.join(process.env.HOME || "", ".camofox-native/pkg/node_modules/camoufox-js/dist/mappings/fonts.config.js"),
].filter(Boolean);

let target = null;
for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
        target = candidate;
        break;
    }
}

if (!target) {
    console.error("could not locate camoufox-js fonts.config.js; tried:");
    for (const c of candidates) console.error("  -", c);
    console.error("pass the path explicitly: node patch-camoufox-fonts.mjs <path>");
    process.exit(1);
}

const src = fs.readFileSync(target, "utf8");
const startMarker = "/* camofox-mac patch start */";
const endMarker = "/* camofox-mac patch end */";
if (src.includes(startMarker)) {
    console.log("already patched:", target);
    process.exit(0);
}

const extras = `
        ${startMarker}
        "Hiragino Sans",
        "Hiragino Kaku Gothic Pro",
        "Hiragino Kaku Gothic ProN",
        "Hiragino Maru Gothic Pro",
        "Hiragino Maru Gothic ProN",
        "Hiragino Mincho Pro",
        "Hiragino Mincho ProN",
        "Osaka",
        "Osaka-Mono",
        "Apple SD Gothic Neo",
        "AppleGothic",
        "AppleMyungjo",
        "PingFang SC",
        "PingFang TC",
        "STSong",
        "STHeiti",
        "STKaiti",
        ${endMarker}`;

const winBlock = /(win:\s*\[)([\s\S]*?)(\n\s*\],)/m;
const m = src.match(winBlock);
if (!m) {
    console.error("could not locate `win: [ ... ]` block in", target);
    process.exit(1);
}

const patched = src.replace(winBlock, `${m[1]}${m[2]}${extras}${m[3]}`);
fs.writeFileSync(target, patched);
console.log("patched:", target);
