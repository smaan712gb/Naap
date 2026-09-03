/// Build stamp for the in-app update check (sideloaded Android has no
/// store auto-update). Bump this AND web/landing/app/version.json together
/// on every APK upload to getnaap.com — the home screen compares the two
/// and shows an update card when the server is newer.
library;

const int kNaapBuild = 20260914;

const String kVersionUrl = 'https://getnaap.com/app/version.json';
const String kDownloadUrl = 'https://getnaap.com/app/naap-latest.apk';
