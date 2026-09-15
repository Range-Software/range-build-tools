#!/usr/bin/env bash
#
# Sign an application bundle for the Mac App Store and wrap it into an
# installer package ready for upload to App Store Connect.
#
# Unlike Developer ID distribution the App Store requires the sandbox
# entitlement, a provisioning profile embedded in the bundle and the two
# "3rd Party Mac Developer" certificates.  Nested code has to be signed from
# the inside out; codesign --deep is explicitly not used, because it would
# apply the application entitlements to every nested binary.

set -euo pipefail

APP_BUNDLE=""
APP_ENTITLEMENTS=""
HELPER_ENTITLEMENTS=""
PROVISION_PROFILE=""
APP_CERT=""
INSTALLER_CERT=""
PKG_FILE=""

usage()
{
    cat <<EOF
Usage: $(basename "$0") [options]

  --app-bundle=PATH           Application bundle to sign (required)
  --app-entitlements=PATH     Entitlements of the application (required)
  --helper-entitlements=PATH  Entitlements of the bundled helper executables (required)
  --provision-profile=PATH    Mac App Store provisioning profile to embed
  --app-cert=NAME             "3rd Party Mac Developer Application: ..." (required)
  --installer-cert=NAME       "3rd Party Mac Developer Installer: ..."
  --pkg=PATH                  Installer package to produce; needs --installer-cert
  --help                      Print this message
EOF
}

for argument in "$@"
do
    case "${argument}" in
        --app-bundle=*)          APP_BUNDLE="${argument#*=}" ;;
        --app-entitlements=*)    APP_ENTITLEMENTS="${argument#*=}" ;;
        --helper-entitlements=*) HELPER_ENTITLEMENTS="${argument#*=}" ;;
        --provision-profile=*)   PROVISION_PROFILE="${argument#*=}" ;;
        --app-cert=*)            APP_CERT="${argument#*=}" ;;
        --installer-cert=*)      INSTALLER_CERT="${argument#*=}" ;;
        --pkg=*)                 PKG_FILE="${argument#*=}" ;;
        --help)                  usage; exit 0 ;;
        *)                       echo "Unknown option '${argument}'" >&2; usage; exit 1 ;;
    esac
done

if [ -z "${APP_BUNDLE}" ] || [ -z "${APP_ENTITLEMENTS}" ] || [ -z "${HELPER_ENTITLEMENTS}" ] || [ -z "${APP_CERT}" ]
then
    echo "Missing mandatory option." >&2
    usage
    exit 1
fi

if [ ! -d "${APP_BUNDLE}" ]
then
    echo "Application bundle '${APP_BUNDLE}' does not exist." >&2
    exit 1
fi

echo "Signing '${APP_BUNDLE}' for the Mac App Store"
echo "  application certificate: ${APP_CERT}"

chmod -R u+w "${APP_BUNDLE}"

# The provisioning profile ties the bundle identifier to the developer account.
if [ -n "${PROVISION_PROFILE}" ]
then
    echo "  embedding provisioning profile '${PROVISION_PROFILE}'"
    cp "${PROVISION_PROFILE}" "${APP_BUNDLE}/Contents/embedded.provisionprofile"
fi

sign_one()
{
    local entitlements="$1"
    local target="$2"
    /usr/bin/codesign --force --timestamp --options runtime \
        --entitlements "${entitlements}" \
        --sign "${APP_CERT}" \
        "${target}"
}

# 1. Loose libraries and plugins.  They carry no entitlements of their own but
#    have to be signed with the same identity as the bundle enclosing them.
echo "  signing libraries and plugins"
while IFS= read -r -d '' library
do
    /usr/bin/codesign --force --timestamp --sign "${APP_CERT}" "${library}"
done < <(/usr/bin/find "${APP_BUNDLE}/Contents" \( -name '*.dylib' -o -name '*.so' \) -type f -print0)

# 2. Frameworks, deepest first, so that a framework containing another one is
#    signed only after its content is final.
echo "  signing frameworks"
while IFS= read -r framework
do
    /usr/bin/codesign --force --timestamp --sign "${APP_CERT}" "${framework}"
done < <(/usr/bin/find "${APP_BUNDLE}/Contents" -name '*.framework' -type d -depth)

# 3. Helper executables next to the main one.  They are spawned by the
#    application and inherit its sandbox.
echo "  signing helper executables"
MAIN_EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${APP_BUNDLE}/Contents/Info.plist")"
for executable in "${APP_BUNDLE}/Contents/MacOS/"*
do
    [ -f "${executable}" ] || continue
    [ -x "${executable}" ] || continue
    if [ "$(basename "${executable}")" = "${MAIN_EXECUTABLE}" ]
    then
        continue
    fi
    echo "    $(basename "${executable}")"
    sign_one "${HELPER_ENTITLEMENTS}" "${executable}"
done

# 4. The bundle itself, carrying the sandbox entitlements.
echo "  signing application bundle"
sign_one "${APP_ENTITLEMENTS}" "${APP_BUNDLE}"

echo "  verifying signature"
/usr/bin/codesign --verify --strict --verbose=2 "${APP_BUNDLE}"

if [ -n "${PKG_FILE}" ]
then
    if [ -z "${INSTALLER_CERT}" ]
    then
        echo "--pkg given without --installer-cert." >&2
        exit 1
    fi
    echo "Building installer package '${PKG_FILE}'"
    echo "  installer certificate: ${INSTALLER_CERT}"
    /usr/bin/productbuild \
        --component "${APP_BUNDLE}" /Applications \
        --sign "${INSTALLER_CERT}" \
        "${PKG_FILE}"
    echo "  verifying package"
    /usr/sbin/pkgutil --check-signature "${PKG_FILE}"
fi

echo "Done."
