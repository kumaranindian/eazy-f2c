@echo off
echo ========================================
echo   Setting up CORS for Firebase Storage
echo ========================================
echo.

echo This script will configure CORS for all Firebase Storage buckets.
echo You need to have gcloud CLI installed.
echo.
echo If you don't have gcloud, install it from:
echo https://cloud.google.com/sdk/docs/install
echo.
pause

cd /d "%~dp0.."

echo Setting CORS for Development (f2c-dev-ddd82)...
gcloud storage buckets update gs://f2c-dev-ddd82.firebasestorage.app --cors-file=cors.json

echo.
echo Setting CORS for Test (f2c-test)...
gcloud storage buckets update gs://f2c-test.firebasestorage.app --cors-file=cors.json

echo.
echo Setting CORS for UAT (f2c-uat)...
gcloud storage buckets update gs://f2c-uat.firebasestorage.app --cors-file=cors.json

echo.
echo Setting CORS for Production (f2c-prod)...
gcloud storage buckets update gs://f2c-prod.firebasestorage.app --cors-file=cors.json

echo.
echo ========================================
echo   CORS Configuration Complete!
echo ========================================
