# bootstrap.ps1
# =============================================================================
# LoyversePOS — Windows PowerShell bootstrap script
#
# USAGE (run from the folder containing this script and all source files):
#   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
#   .\bootstrap.ps1
# =============================================================================

$ErrorActionPreference = "Stop"
$ProjectName = "loyverse_pos"

function Write-Step($msg)  { Write-Host "▶ $msg" -ForegroundColor Green }
function Write-Info($msg)  { Write-Host "  $msg"  -ForegroundColor Cyan  }
function Write-Warn($msg)  { Write-Host "  ⚠ $msg" -ForegroundColor Yellow }

Write-Host ""
Write-Host "  LoyversePOS — Point of Sale Bootstrap" -ForegroundColor Cyan
Write-Host ""

# ── Prerequisites ──────────────────────────────────────────────────────────
Write-Step "Checking prerequisites..."

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Flutter not found. Install from https://docs.flutter.dev/get-started/install" -ForegroundColor Red
    exit 1
}
$flv = (flutter --version 2>&1 | Select-Object -First 1)
Write-Info "Found: $flv"

# ── Create directory ────────────────────────────────────────────────────────
Write-Step "Creating project directory: .\$ProjectName"
New-Item -ItemType Directory -Force -Path $ProjectName | Out-Null
Set-Location $ProjectName

# ── Folder structure ────────────────────────────────────────────────────────
Write-Step "Creating folder structure..."
$Dirs = @(
    "lib\models",
    "lib\providers",
    "lib\services",
    "lib\ui\theme",
    "lib\ui\widgets",
    "lib\ui\screens\auth",
    "lib\ui\screens\shell",
    "lib\ui\screens\dashboard",
    "lib\ui\screens\pos",
    "lib\ui\screens\inventory",
    "lib\ui\screens\customers",
    "lib\ui\screens\sales",
    "lib\ui\screens\settings",
    "assets\images",
    "assets\icons",
    "assets\fonts",
    "android\app\src\main\res\xml",
    "android\app\src\main\res\mipmap-hdpi",
    "android\app\src\main\res\mipmap-xhdpi",
    "android\app\src\main\res\mipmap-xxhdpi",
    "android\app\src\main\res\mipmap-xxxhdpi",
    "windows\runner"
)
foreach ($d in $Dirs) {
    New-Item -ItemType Directory -Force -Path $d | Out-Null
}
Write-Info "Folder structure created ✓"

# ── Copy source files ───────────────────────────────────────────────────────
Write-Step "Copying source files..."

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Files = @(
    "pubspec.yaml",
    "codemagic.yaml",
    "README.md",
    ".gitignore",
    "lib\main.dart",
    "lib\firebase_options.dart",
    "lib\models\models.dart",
    "lib\models\models.g.dart",
    "lib\providers\providers.dart",
    "lib\services\firebase_service.dart",
    "lib\services\local_storage_service.dart",
    "lib\services\print_service.dart",
    "lib\ui\theme\app_theme.dart",
    "lib\ui\widgets\shared_widgets.dart",
    "lib\ui\screens\auth\auth_screen.dart",
    "lib\ui\screens\shell\app_shell.dart",
    "lib\ui\screens\dashboard\dashboard_screen.dart",
    "lib\ui\screens\pos\pos_screen.dart",
    "lib\ui\screens\pos\checkout_dialog.dart",
    "lib\ui\screens\pos\variant_selector_dialog.dart",
    "lib\ui\screens\pos\customer_selector.dart",
    "lib\ui\screens\inventory\inventory_screen.dart",
    "lib\ui\screens\customers\customers_screen.dart",
    "lib\ui\screens\sales\sales_screen.dart",
    "lib\ui\screens\settings\settings_screen.dart",
    "android\app\build.gradle",
    "android\build.gradle",
    "android\gradle.properties",
    "android\settings.gradle",
    "android\app\proguard-rules.pro",
    "android\app\src\main\AndroidManifest.xml",
    "android\app\src\main\res\xml\file_paths.xml",
    "windows\runner\Runner.rc"
)

$Copied = 0
foreach ($f in $Files) {
    $src = Join-Path $ScriptDir $f
    if (Test-Path $src) {
        $dst = $f
        $dstDir = Split-Path $dst -Parent
        if ($dstDir -and -not (Test-Path $dstDir)) {
            New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
        }
        Copy-Item $src $dst -Force
        $Copied++
    }
}
Write-Info "$Copied source files copied ✓"

# ── flutter pub get ─────────────────────────────────────────────────────────
Write-Step "Running flutter pub get..."
flutter pub get

# ── build_runner ────────────────────────────────────────────────────────────
Write-Step "Running build_runner for Hive adapters..."
try {
    dart run build_runner build --delete-conflicting-outputs
    Write-Info "Hive adapters generated ✓"
} catch {
    Write-Warn "build_runner failed — run manually: dart run build_runner build"
}

# ── git init ────────────────────────────────────────────────────────────────
if (Get-Command git -ErrorAction SilentlyContinue) {
    if (-not (Test-Path ".git")) {
        Write-Step "Initialising git repository..."
        git init -q
        git add -A
        git commit -m "chore: initial LoyversePOS project setup" -q
        Write-Info "Git repository initialised ✓"
    }
}

# ── Done ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✅  LoyversePOS is ready!" -ForegroundColor Green
Write-Host "════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor White
Write-Host ""
Write-Host "  1. Configure Firebase:"
Write-Host "     dart pub global activate flutterfire_cli" -ForegroundColor Cyan
Write-Host "     flutterfire configure --project=YOUR_PROJECT_ID" -ForegroundColor Cyan
Write-Host ""
Write-Host "  2. Run on Android:"
Write-Host "     flutter run -d <device-id>" -ForegroundColor Cyan
Write-Host ""
Write-Host "  3. Run on Windows:"
Write-Host "     flutter run -d windows" -ForegroundColor Cyan
Write-Host ""
Write-Host "  4. Push to GitHub & connect Codemagic:"
Write-Host "     https://codemagic.io" -ForegroundColor Cyan
Write-Host ""
Write-Host "  See README.md for full setup instructions."
Write-Host ""
