@echo off
echo ========================================
echo   Deploying F2C to PRODUCTION
echo ========================================
echo.

echo Step 1: Building Flutter Web for Production...
cd /d "%~dp0.."
call flutter build web --release -t lib/main_prod.dart
if %errorlevel% neq 0 (
    echo Build failed!
    exit /b %errorlevel%
)

echo.
echo Step 2: Deploying to Firebase Hosting (f2c-prod)...
call firebase use f2c-prod
call firebase deploy --only hosting
if %errorlevel% neq 0 (
    echo Deployment failed!
    exit /b %errorlevel%
)

echo.
echo Step 3: Deploying Firestore Rules and Indexes...
call firebase deploy --only firestore
if %errorlevel% neq 0 (
    echo Firestore deployment failed!
    exit /b %errorlevel%
)

echo.
echo Step 4: Deploying Storage Rules...
call firebase deploy --only storage
if %errorlevel% neq 0 (
    echo Storage deployment failed!
    exit /b %errorlevel%
)

echo.
echo ========================================
echo   PRODUCTION Deployment Complete!
echo ========================================
echo   - Web App Deployed
echo   - Firestore Rules Updated
echo   - Firestore Indexes Updated
echo   - Storage Rules Updated
echo ========================================
echo.
call firebase open hosting:site
