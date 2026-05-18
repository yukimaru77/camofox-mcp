#!/usr/bin/env node
// scripts/macos/patch-camofox-tab-mode.mjs
//
// Playwright's Firefox driver opens every `context.newPage()` as a separate
// top-level BrowserWindow. camofox-browser uses newPage() on POST /tabs
// (both the staged-first-tab path and the regular path), so two parallel
// MCP requests end up creating two OS-level Camoufox windows even though
// they share a Playwright BrowserContext.
//
// Firefox does support multiple tabs in one window — it's only `newPage()`
// that can't reach that codepath. When a page calls `window.open(url)`,
// Firefox honors `browser.link.open_newwindow=3` /
// `browser.link.open_newwindow.restriction=0` and opens the new page as a
// *tab* inside the existing window. Playwright still captures that popup
// as a Page object and routes commands to it normally.
//
// This patch rewrites both newPage() sites in POST /tabs:
//   - If the context has zero pages yet, fall back to context.newPage()
//     (the path that needs to spawn the initial window).
//   - Otherwise, run `window.open(url)` from an existing page, wait for
//     the popup event, and use that Page as the new tab. The popup
//     arrives in the same window as a tab.
//
// Requires user.js in the Camoufox profile to set:
//   user_pref("browser.link.open_newwindow", 3);
//   user_pref("browser.link.open_newwindow.restriction", 0);
// (Shipped in scripts/macos/profile-user.js.)
//
// Idempotent (marker-guarded). Re-run after `npm install`.

import fs from "node:fs";
import path from "node:path";

const home = process.env.HOME || "";
const candidates = [
    process.env.CAMOFOX_BROWSER_PKG_ROOT,
    path.join(home, ".camofox-native/pkg/node_modules/camofox-browser"),
].filter(Boolean);

let pkgRoot = null;
for (const c of candidates) {
    if (fs.existsSync(path.join(c, "dist/src/routes/core.js"))) {
        pkgRoot = c;
        break;
    }
}
if (!pkgRoot) {
    console.error("camofox-browser package not found");
    process.exit(1);
}

const coreJs = path.join(pkgRoot, "dist/src/routes/core.js");
const startMarker = "/* camofox-mac tab-mode patch */";

const tabModeShim = (label) => `${startMarker}
            let page;
            const __existingPages = session.context.pages().filter((p) => !p.isClosed?.());
            if (__existingPages.length > 0 && url) {
                const __donor = __existingPages[0];
                const __popupPromise = session.context.waitForEvent('page', { timeout: 20000 });
                try {
                    await __donor.evaluate((u) => { window.open(u, '_blank'); }, url);
                    page = await __popupPromise;
                } catch (__err) {
                    page = await session.context.newPage();
                }
            } else {
                page = await session.context.newPage();
            }
            /* end ${label} */`;

let src = fs.readFileSync(coreJs, "utf8");
if (src.includes(startMarker)) {
    console.log("already patched:", coreJs);
    process.exit(0);
}

// There are two `session.context.newPage()` callsites in POST /tabs — the
// staged (first-tab) path and the regular path. Patch both.
const original = "            const page = await session.context.newPage();";
const occurrences = src.split(original).length - 1;
if (occurrences < 2) {
    console.error(`expected 2 'session.context.newPage()' callsites; found ${occurrences}`);
    process.exit(1);
}

src = src.replace(original, tabModeShim("staged"));
src = src.replace(original, tabModeShim("regular"));

fs.writeFileSync(coreJs, src);
console.log(`patched ${occurrences} callsites in:`, coreJs);
console.log("done. Restart camofox-browser to apply.");
