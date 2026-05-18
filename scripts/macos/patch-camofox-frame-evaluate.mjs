#!/usr/bin/env node
// scripts/macos/patch-camofox-frame-evaluate.mjs
//
// camofox-browser's `/tabs/:tabId/evaluate-extended` runs JS in the page
// context only. ChatGPT renders Deep Research output inside a cross-origin
// iframe (https://connector_openai_deep_research.web-sandbox.oaiusercontent.com/...),
// which page-context JS cannot read. Playwright's frame API can.
//
// This script patches camofox-browser in place to add an optional
// `frameUrl` body parameter to `/tabs/:tabId/evaluate-extended`. When
// provided, the route runs the expression against the first frame whose
// URL contains the substring (or matches the regex) — using Playwright's
// frame.evaluate() under the hood, which works across origins.
//
// Idempotent (marker-guarded). Re-run after `npm install`.
//
//     node ~/camofox-mcp/scripts/macos/patch-camofox-frame-evaluate.mjs

import fs from "node:fs";
import path from "node:path";

const home = process.env.HOME || "";
const baseCandidates = [
    process.env.CAMOFOX_BROWSER_PKG_ROOT,
    path.join(home, ".camofox-native/pkg/node_modules/camofox-browser"),
].filter(Boolean);

let pkgRoot = null;
for (const c of baseCandidates) {
    if (fs.existsSync(path.join(c, "dist/src/routes/core.js"))) {
        pkgRoot = c;
        break;
    }
}
if (!pkgRoot) {
    console.error("camofox-browser package not found in:", baseCandidates);
    process.exit(1);
}

const tabJsPath = path.join(pkgRoot, "dist/src/services/tab.js");
const coreJsPath = path.join(pkgRoot, "dist/src/routes/core.js");

const startMarker = "/* camofox-mac frame-evaluate patch start */";
const endMarker = "/* camofox-mac frame-evaluate patch end */";

// --- Patch 1: tab.js _evaluateInternal — accept params.frameUrl and route
//     evaluate to the matching frame via Playwright's frame() API.
{
    const src = fs.readFileSync(tabJsPath, "utf8");
    if (src.includes(startMarker)) {
        console.log("tab.js already patched:", tabJsPath);
    } else {
        const oldLine = "return Promise.race([page.evaluate(params.expression), timeoutPromise]);";
        if (!src.includes(oldLine)) {
            console.error("tab.js: target line not found; bailing out");
            process.exit(1);
        }
        const replacement = `${startMarker}
                let evaluator = page;
                if (params && params.frameUrl) {
                    const needle = String(params.frameUrl);
                    const re = needle.startsWith("/") && needle.lastIndexOf("/") > 0
                        ? new RegExp(needle.slice(1, needle.lastIndexOf("/")), needle.slice(needle.lastIndexOf("/") + 1))
                        : null;
                    const frames = page.frames();
                    const match = frames.find((f) => {
                        const u = f.url() || "";
                        if (re) return re.test(u);
                        return u.indexOf(needle) >= 0;
                    });
                    if (!match) {
                        throw new Error("frame matching frameUrl not found: " + needle);
                    }
                    evaluator = match;
                }
                return Promise.race([evaluator.evaluate(params.expression), timeoutPromise]);
                ${endMarker}`;
        const patched = src.replace(oldLine, replacement);
        if (patched === src) {
            console.error("tab.js: replace produced no change; aborting");
            process.exit(1);
        }
        fs.writeFileSync(tabJsPath, patched);
        console.log("patched:", tabJsPath);
    }
}

// --- Patch 2: core.js — read frameUrl from req.body and forward it to
//     evaluateTabExtended.
{
    const src = fs.readFileSync(coreJsPath, "utf8");
    if (src.includes(startMarker)) {
        console.log("core.js already patched:", coreJsPath);
    } else {
        const oldExtract = "const { expression, timeout } = req.body;";
        if (!src.includes(oldExtract)) {
            console.error("core.js: target destructure not found");
            process.exit(1);
        }
        const newExtract = `const { expression, timeout, frameUrl } = req.body; ${startMarker} ${endMarker}`;
        let patched = src.replace(oldExtract, newExtract);
        // Now pass frameUrl into the evaluateTabExtended call.
        const oldCall = "(0, tab_1.evaluateTabExtended)(tabId, tabState, { expression, timeout: effectiveTimeout })";
        const newCall = "(0, tab_1.evaluateTabExtended)(tabId, tabState, { expression, timeout: effectiveTimeout, frameUrl })";
        if (!patched.includes(oldCall)) {
            console.error("core.js: evaluateTabExtended call site not found");
            process.exit(1);
        }
        patched = patched.replace(oldCall, newCall);
        fs.writeFileSync(coreJsPath, patched);
        console.log("patched:", coreJsPath);
    }
}

console.log("done. Restart camofox-browser to apply.");
