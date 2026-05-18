// Template user.js for the Camoufox persistent profile on macOS.
//
// Copy this file to $CAMOFOX_PROFILES_DIR/<userId>/user.js (e.g.
// ~/.camofox-native/profiles/default/user.js). Firefox/Camoufox loads
// user.js on every launch, so values here override any matching pref
// Camoufox wrote into prefs.js.
//
// Why this file exists: Camoufox spoofs the JS-reported font list to
// Windows names (Yu Gothic, MS UI Gothic, ...). Those fonts do not exist
// on macOS, so any CSS `font-family:` that names them falls through to a
// renderer fallback whose default does not include any CJK glyphs ->
// Japanese, Korean, and Chinese render as 文字化け (mojibake). The prefs
// below pin the per-language default to the macOS Hiragino / PingFang /
// Apple Gothic families, which actually exist on the system.
//
// Note: the font.system.whitelist override is intentionally non-empty —
// Camoufox re-applies a Windows-only whitelist at runtime, so even if we
// set this to "" here it is overwritten. The whitelist is instead extended
// at the camoufox-js layer by scripts/macos/patch-camoufox-fonts.mjs.

// Japanese (ja).
user_pref("font.name.serif.ja", "Hiragino Mincho ProN");
user_pref("font.name.sans-serif.ja", "Hiragino Sans");
user_pref("font.name.monospace.ja", "Osaka-Mono");
user_pref("font.default.ja", "sans-serif");

// Korean (ko).
user_pref("font.name.serif.ko", "AppleMyungjo");
user_pref("font.name.sans-serif.ko", "Apple SD Gothic Neo");
user_pref("font.default.ko", "sans-serif");

// Simplified Chinese (zh-CN).
user_pref("font.name.serif.zh-CN", "STSong");
user_pref("font.name.sans-serif.zh-CN", "PingFang SC");
user_pref("font.default.zh-CN", "sans-serif");

// Traditional Chinese (zh-TW).
user_pref("font.name.serif.zh-TW", "LiSong Pro");
user_pref("font.name.sans-serif.zh-TW", "PingFang TC");
user_pref("font.default.zh-TW", "sans-serif");
