@echo off
setlocal

cd /d "%~dp0"

echo [INFO] Building Flutter release APK for arm64-v8a...
call flutter build apk --release --target-platform android-arm64
if errorlevel 1 (
    echo [ERROR] Build failed.
    exit /b 1
)

set "APK_PATH=build\app\outputs\flutter-apk\app-release.apk"

if exist "%APK_PATH%" (
    echo [SUCCESS] Build finished.
    echo [OUTPUT] %CD%\%APK_PATH%
) else (
    echo [WARN] Build command finished, but APK was not found at:
    echo [WARN] %CD%\%APK_PATH%
    exit /b 1
)

endlocal
