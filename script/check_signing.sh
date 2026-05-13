#!/usr/bin/env bash
set -euo pipefail

APP_NAME="WinEventLogViewer"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "========================================"
echo "  Code Signing Setup Check"
echo "========================================"
echo ""

# Check for Developer ID Application certificate
echo "1. Checking for Developer ID Application certificates..."
DEV_ID_CERTS=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" || true)
if [[ -n "$DEV_ID_CERTS" ]]; then
  echo "   ✓ Found Developer ID Application certificate(s):"
  echo "$DEV_ID_CERTS" | sed 's/^/     /'
else
  echo "   ✗ No Developer ID Application certificate found."
  echo ""
  echo "   You have an Apple Development certificate, but for distributing"
  echo "   outside the App Store you need a Developer ID Application certificate."
  echo ""
  echo "   To create one:"
  echo "   1. Go to https://developer.apple.com/account/resources/certificates/list"
  echo "   2. Click '+' to create a new certificate"
  echo "   3. Select 'Developer ID Application'"
  echo "   4. Follow the instructions to create a CSR and download the certificate"
  echo "   5. Double-click the .cer file to install it in your Keychain"
fi

echo ""
echo "2. Checking for Apple Development certificates..."
DEV_CERTS=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" || true)
if [[ -n "$DEV_CERTS" ]]; then
  echo "   ✓ Found Apple Development certificate(s):"
  echo "$DEV_CERTS" | sed 's/^/     /'
else
  echo "   ✗ No Apple Development certificate found."
fi

echo ""
echo "3. Checking notarization prerequisites..."
if command -v xcrun >/dev/null 2>&1 && xcrun --find notarytool >/dev/null 2>&1; then
  echo "   ✓ notarytool is available"
else
  echo "   ✗ notarytool not found. Install Xcode Command Line Tools."
fi

echo ""
echo "4. Checking entitlements file..."
ENTITLEMENTS_FILE="$ROOT_DIR/Resources/$APP_NAME.entitlements"
if [[ -f "$ENTITLEMENTS_FILE" ]]; then
  echo "   ✓ Entitlements file exists: Resources/$APP_NAME.entitlements"
else
  echo "   ✗ Entitlements file not found"
fi

echo ""
echo "5. Environment variables..."
if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  echo "   ✓ CODESIGN_IDENTITY is set: $CODESIGN_IDENTITY"
else
  echo "   ✗ CODESIGN_IDENTITY is not set"
fi

if [[ -n "${NOTARIZATION_USERNAME:-}" ]]; then
  echo "   ✓ NOTARIZATION_USERNAME is set"
else
  echo "   ✗ NOTARIZATION_USERNAME is not set"
fi

if [[ -n "${NOTARIZATION_PASSWORD:-}" ]]; then
  echo "   ✓ NOTARIZATION_PASSWORD is set"
else
  echo "   ✗ NOTARIZATION_PASSWORD is not set"
fi

if [[ -n "${NOTARIZATION_TEAM_ID:-}" ]]; then
  echo "   ✓ NOTARIZATION_TEAM_ID is set: $NOTARIZATION_TEAM_ID"
else
  echo "   ⚠ NOTARIZATION_TEAM_ID is not set (optional, only needed for multi-team accounts)"
fi

echo ""
echo "========================================"
echo ""

if [[ -n "$DEV_ID_CERTS" && -n "${CODESIGN_IDENTITY:-}" && -n "${NOTARIZATION_USERNAME:-}" && -n "${NOTARIZATION_PASSWORD:-}" ]]; then
  echo "✓ Ready to build a signed and notarized DMG!"
  echo ""
  echo "Run: ./script/create_dmg.sh"
else
  echo "⚠ Missing items required for signed distribution."
  echo ""
  echo "To test with ad-hoc signing (no Gatekeeper compliance):"
  echo "  ./script/create_dmg.sh"
  echo ""
  echo "For full signing and notarization, see SIGNING.md"
fi

echo ""
