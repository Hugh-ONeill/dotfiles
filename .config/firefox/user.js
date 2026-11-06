// Shared Firefox prefs for every machine
// Copied into each profile's user.js by ~/.config/themes/lib/apps/firefox.sh,
// followed by ~/.config/firefox/user-local.js (untracked, per-machine) if present.
// user.js is re-applied on every startup, so changing these in the UI won't stick.

// ============================================================
// CUSTOMIZATION
// ============================================================

// needed for userChrome.css / theme-colors.css
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// -------------------- Fonts --------------------
user_pref("font.name.monospace.x-western", "GohuFont 14 Nerd Font Mono");
user_pref("font.name.sans-serif.x-western", "Mononoki Nerd Font");
user_pref("font.name.serif.x-western", "FiraCode Nerd Font");
user_pref("font.size.monospace.x-western", 14);

// -------------------- UI --------------------
user_pref("browser.aboutConfig.showWarning", false);
user_pref("browser.bookmarks.editDialog.showForNewBookmarks", false);
user_pref("browser.toolbars.bookmarks.visibility", "never");
user_pref("browser.tabs.inTitlebar", 1);
// compact density (tighter toolbar and tab heights)
user_pref("browser.compactmode.show", true);
user_pref("browser.uidensity", 1);
// dark browser chrome + dark prefers-color-scheme for sites
user_pref("browser.theme.content-theme", 0);
user_pref("layout.css.prefers-color-scheme.content-override", 0);
user_pref("devtools.toolbox.host", "right");
// dim tabs that were unloaded to save memory
user_pref("browser.tabs.fadeOutUnloadedTabs", true);
// tab notes (experimental, off by default)
user_pref("browser.tabs.notes.enabled", true);
// sidebar: bitwarden + passwords only
user_pref("sidebar.main.tools", "{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d},passwords");

// ============================================================
// ADDRESS BAR & NEW TAB
// ============================================================

// -------------------- Address Bar --------------------
user_pref("browser.search.suggest.enabled", false);
user_pref("browser.urlbar.suggest.bookmark", false);
user_pref("browser.urlbar.suggest.engines", false);
user_pref("browser.urlbar.suggest.history", false);
user_pref("browser.urlbar.suggest.openpage", false);
user_pref("browser.urlbar.suggest.recentsearches", false);
user_pref("browser.urlbar.suggest.searches", false);
user_pref("browser.urlbar.suggest.topsites", false);
user_pref("browser.urlbar.suggest.quicksuggest.all", false);
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);

// -------------------- New Tab --------------------
user_pref("browser.newtabpage.activity-stream.showSearch", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.showWeather", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.widgets.clocks.enabled", false);
user_pref("browser.newtabpage.activity-stream.widgets.crossword.enabled", false);
user_pref("browser.newtabpage.activity-stream.widgets.pictureOfTheDay.enabled", false);

// -------------------- Nags --------------------
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false);
user_pref("extensions.htmlaboutaddons.recommendations.enabled", false);
user_pref("browser.shopping.experience2023.active", false);

// ============================================================
// PRIVACY & SECURITY
// ============================================================

// -------------------- Telemetry & Studies --------------------
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("app.normandy.enabled", false);
// gradual feature rollouts (still enroll with studies off)
user_pref("nimbus.rollouts.enabled", false);
// ad "privacy-preserving attribution"
user_pref("dom.private-attribution.submission.enabled", false);

// -------------------- Tracking & Transport --------------------
user_pref("browser.contentblocking.category", "strict");
user_pref("privacy.globalprivacycontrol.enabled", true);
user_pref("dom.security.https_only_mode", true);

// -------------------- AI Features --------------------
user_pref("browser.ml.chat.enabled", false);
user_pref("browser.ml.chat.sidebar", false);
user_pref("browser.ml.linkPreview.enabled", false);
