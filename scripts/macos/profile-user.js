// camofox-mcp macOS: force the Japanese font fallback to the macOS Hiragino
// family. Camoufox spoofs the JS-reported font list to Windows names
// (MS UI Gothic / Yu Gothic / ...), and those fonts do not exist on macOS,
// so any page CSS that requests them ends up in a fallback chain whose
// default does not support CJK -> 文字化け. These prefs override the
// fallback at the renderer level (independent of the spoofed font list)
// so Japanese text always picks a real macOS font.

// Camoufox sets font.system.whitelist to a Windows-only font list, which
// hides the macOS Hiragino family from the *renderer* itself (not just JS).
// Empty whitelist = no restriction; the renderer sees all installed system
// fonts and can use Hiragino for the prefs below.
user_pref("font.system.whitelist", "");
user_pref("font.name.serif.ja", "Hiragino Mincho ProN");
user_pref("font.name.sans-serif.ja", "Hiragino Sans");
user_pref("font.name.monospace.ja", "Osaka-Mono");
user_pref("font.default.ja", "sans-serif");

// Force any new top-level page to open as a tab inside the existing
// Camoufox window instead of as a separate OS window. Playwright's
// context.newPage() — which camofox-browser uses on POST /tabs — would
// otherwise spawn a fresh BrowserWindow each call, which is visually
// disruptive when running parallel MCP requests.
//   3 = open new windows in a new tab instead
//   0 (restriction) = the above applies to every window.open / new page,
//                     not only target=_blank links.
user_pref("browser.link.open_newwindow", 3);
user_pref("browser.link.open_newwindow.restriction", 0);

// Same for Korean / Simplified Chinese / Traditional Chinese, since the
// spoofed list includes "Malgun Gothic" etc. that also don't exist on macOS.
user_pref("font.name.serif.ko", "AppleMyungjo");
user_pref("font.name.sans-serif.ko", "Apple SD Gothic Neo");
user_pref("font.default.ko", "sans-serif");
user_pref("font.name.serif.zh-CN", "STSong");
user_pref("font.name.sans-serif.zh-CN", "PingFang SC");
user_pref("font.default.zh-CN", "sans-serif");
user_pref("font.name.serif.zh-TW", "LiSong Pro");
user_pref("font.name.sans-serif.zh-TW", "PingFang TC");
user_pref("font.default.zh-TW", "sans-serif");
