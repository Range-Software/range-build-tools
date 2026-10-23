## Version 1.1.0

### Improvements

#### Mac App Store

- `mac_app_store.sh` signs an application bundle for the Mac App Store and optionally
  wraps it into an installer package ready for upload to App Store Connect
  (`--pkg` together with `--installer-cert`)
- Nested code is signed from the inside out - loose libraries and plugins, frameworks
  deepest first, helper executables and finally the bundle itself. `codesign --deep`
  is not used, as it would apply the application entitlements to every nested binary.
  The signature is verified once the bundle is signed
- A provisioning profile given with `--provision-profile` is embedded in the bundle
- `packaging/macos/Info.plist.in`: bundle information template, including the
  application category and the export compliance (`ITSAppUsesNonExemptEncryption`) keys
- `packaging/macos/app.entitlements.in`: sandbox entitlements of the application -
  network client (Range Cloud, AI assistant, update check), read and write access to
  files selected by the user, and printing
- The application entitlements carry the application and team identifiers
  (`@MACOS_TEAM_ID@`, `@MACOS_BUNDLE_IDENTIFIER@`), which must match the embedded
  provisioning profile. Without them App Store Connect rejects the upload (ITMS-90886)
- `packaging/macos/helper.entitlements.in`: helper executables spawned by the
  application (`fea-solver`, `openssl`) inherit the sandbox of their parent

#### Microsoft Store

- `packaging/windows/AppxManifest.xml.in`: MSIX package manifest template for a full
  trust Windows desktop application. Package identity, publisher and version are
  filled in from the project configuration
- The manifest declares Czech, German, Spanish, French, Italian, Polish and Ukrainian
  resource languages in addition to English and Slovak, matching the languages the
  application is translated to

## Version 1.0.0

Initial release
