#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh  —  Unpack LoyversePOS from this repo into a fresh Flutter project
#
# USAGE (Linux / macOS / WSL):
#   chmod +x bootstrap.sh && ./bootstrap.sh
#
# USAGE (Git Bash on Windows):
#   bash bootstrap.sh
#
# The script:
#   1. Verifies Flutter is installed
#   2. Creates the folder structure
#   3. Runs `flutter pub get`
#   4. Prints next steps
# =============================================================================

set -euo pipefail

PROJECT="loyverse_pos"
BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RESET="\033[0m"

banner() {
  echo -e "${CYAN}"
  echo "  ██╗      ██████╗ ██╗   ██╗███████╗██████╗ ███████╗███████╗"
  echo "  ██║     ██╔═══██╗╚██╗ ██╔╝██╔════╝██╔══██╗██╔════╝██╔════╝"
  echo "  ██║     ██║   ██║ ╚████╔╝ █████╗  ██████╔╝███████╗█████╗  "
  echo "  ██║     ██║   ██║  ╚██╔╝  ██╔══╝  ██╔══██╗╚════██║██╔══╝  "
  echo "  ███████╗╚██████╔╝   ██║   ███████╗██║  ██║███████║███████╗"
  echo "  ╚══════╝ ╚═════╝    ╚═╝   ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝"
  echo "  POS — Production-Ready Flutter Point of Sale"
  echo -e "${RESET}"
}

step() { echo -e "${BOLD}${GREEN}▶ $1${RESET}"; }
info() { echo -e "  ${CYAN}$1${RESET}"; }
warn() { echo -e "  ${YELLOW}⚠  $1${RESET}"; }

banner
step "Checking prerequisites..."

if ! command -v flutter &>/dev/null; then
  echo "Flutter not found. Install from https://docs.flutter.dev/get-started/install"
  exit 1
fi

FLUTTER_VERSION=$(flutter --version 2>&1 | head -1)
info "Found: $FLUTTER_VERSION"

if ! command -v git &>/dev/null; then
  warn "git not found. Continuing without git init."
fi

step "Creating project directory: ./$PROJECT"
mkdir -p "$PROJECT"
cd "$PROJECT"

step "Creating folder structure..."
dirs=(
  "lib/models"
  "lib/providers"
  "lib/services"
  "lib/ui/theme"
  "lib/ui/widgets"
  "lib/ui/screens/auth"
  "lib/ui/screens/shell"
  "lib/ui/screens/dashboard"
  "lib/ui/screens/pos"
  "lib/ui/screens/inventory"
  "lib/ui/screens/customers"
  "lib/ui/screens/sales"
  "lib/ui/screens/settings"
  "assets/images"
  "assets/icons"
  "assets/fonts"
  "android/app/src/main/res/xml"
  "android/app/src/main/res/mipmap-hdpi"
  "android/app/src/main/res/mipmap-mdpi"
  "android/app/src/main/res/mipmap-xhdpi"
  "android/app/src/main/res/mipmap-xxhdpi"
  "android/app/src/main/res/mipmap-xxxhdpi"
  "windows/runner"
)

for d in "${dirs[@]}"; do
  mkdir -p "$d"
done

info "Folder structure created ✓"

step "Checking if source files exist in parent directory..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR"

# Copy all source files if they exist alongside this script
copy_if_exists() {
  local src="$SOURCE_DIR/$1"
  local dst="./$1"
  if [ -f "$src" ]; then
    cp "$src" "$dst"
    info "Copied: $1"
  fi
}

FILES=(
  "pubspec.yaml"
  "codemagic.yaml"
  "README.md"
  ".gitignore"
  "lib/main.dart"
  "lib/firebase_options.dart"
  "lib/models/models.dart"
  "lib/models/models.g.dart"
  "lib/providers/providers.dart"
  "lib/services/firebase_service.dart"
  "lib/services/local_storage_service.dart"
  "lib/services/print_service.dart"
  "lib/ui/theme/app_theme.dart"
  "lib/ui/widgets/shared_widgets.dart"
  "lib/ui/screens/auth/auth_screen.dart"
  "lib/ui/screens/shell/app_shell.dart"
  "lib/ui/screens/dashboard/dashboard_screen.dart"
  "lib/ui/screens/pos/pos_screen.dart"
  "lib/ui/screens/pos/checkout_dialog.dart"
  "lib/ui/screens/pos/variant_selector_dialog.dart"
  "lib/ui/screens/pos/customer_selector.dart"
  "lib/ui/screens/inventory/inventory_screen.dart"
  "lib/ui/screens/customers/customers_screen.dart"
  "lib/ui/screens/sales/sales_screen.dart"
  "lib/ui/screens/settings/settings_screen.dart"
  "android/app/build.gradle"
  "android/build.gradle"
  "android/gradle.properties"
  "android/settings.gradle"
  "android/app/proguard-rules.pro"
  "android/app/src/main/AndroidManifest.xml"
  "android/app/src/main/res/xml/file_paths.xml"
  "windows/runner/Runner.rc"
)

COPIED=0
for f in "${FILES[@]}"; do
  src="$SOURCE_DIR/$f"
  if [ -f "$src" ] && [ "$src" != "./$f" ]; then
    dst="./$f"
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    COPIED=$((COPIED + 1))
  fi
done

info "$COPIED source files copied ✓"

step "Running flutter pub get..."
flutter pub get

# Optionally run build_runner for Hive adapters
if flutter pub deps 2>/dev/null | grep -q build_runner; then
  step "Running build_runner (Hive adapters)..."
  dart run build_runner build --delete-conflicting-outputs || warn "build_runner failed — run manually if needed"
fi

# Git init
if command -v git &>/dev/null && [ ! -d ".git" ]; then
  step "Initialising git repository..."
  git init -q
  git add -A
  git commit -m "chore: initial LoyversePOS project setup" -q
  info "Git repository initialised ✓"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}  ✅  LoyversePOS is ready!${RESET}"
echo -e "${GREEN}════════════════════════════════════════════${RESET}"
echo ""
echo -e "${BOLD}Next Steps:${RESET}"
echo ""
echo "  1. Configure Firebase:"
echo -e "     ${CYAN}dart pub global activate flutterfire_cli${RESET}"
echo -e "     ${CYAN}flutterfire configure --project=YOUR_PROJECT_ID${RESET}"
echo ""
echo "  2. Run on Android:"
echo -e "     ${CYAN}flutter run -d <device-id>${RESET}"
echo ""
echo "  3. Run on Windows:"
echo -e "     ${CYAN}flutter run -d windows${RESET}"
echo ""
echo "  4. Push to GitHub and connect to Codemagic:"
echo "     https://codemagic.io"
echo ""
echo "  See README.md for full setup instructions."
echo ""
