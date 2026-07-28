# F2C Complete Setup Guide

This comprehensive guide will walk you through setting up the F2C application from scratch.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Firebase Configuration](#firebase-configuration)
4. [Code Generation](#code-generation)
5. [Running the Application](#running-the-application)
6. [Creating Admin User](#creating-admin-user)
7. [Testing](#testing)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

- **Flutter SDK** >= 3.0.0
  ```bash
  flutter --version
  ```

- **Dart SDK** >= 3.0.0 (comes with Flutter)

- **Git**
  ```bash
  git --version
  ```

- **Firebase CLI**
  ```bash
  npm install -g firebase-tools
  firebase --version
  ```

- **IDE** (Choose one)
  - Android Studio with Flutter plugin
  - VS Code with Flutter extension

### Optional Software

- **Node.js** (for Firebase CLI)
- **Android Studio** (for Android development)
- **Xcode** (for iOS development - macOS only)

---

## Initial Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd eazy-f2c
```

### 2. Install Flutter Dependencies

```bash
flutter pub get
```

### 3. Install Script Dependencies

```bash
cd scripts
flutter pub get
cd ..
```

### 4. Verify Flutter Installation

```bash
flutter doctor
```

Fix any issues reported by `flutter doctor`.

---

## Firebase Configuration

### Step 1: Create Firebase Projects

Create **four** Firebase projects in [Firebase Console](https://console.firebase.google.com/):

1. **f2c-dev** (Development)
2. **f2c-test** (Testing)
3. **f2c-uat** (UAT)
4. **f2c-prod** (Production)

### Step 2: Enable Firebase Services

For **each** project:

1. **Authentication**
   - Go to Authentication → Sign-in method
   - Enable "Email/Password"
   - Save

2. **Firestore Database**
   - Go to Firestore Database
   - Create database
   - Start in **production mode**
   - Choose location (closest to users)

3. **Storage**
   - Go to Storage
   - Get started
   - Start in **production mode**

### Step 3: Register Apps

For each Firebase project, register:

#### Android App

1. Go to Project Settings → General
2. Click "Add app" → Android
3. Package names:
   - Dev: `com.f2c.app.dev`
   - Test: `com.f2c.app.test`
   - UAT: `com.f2c.app.uat`
   - Prod: `com.f2c.app`
4. Download `google-services.json`
5. Place in appropriate folder:
   ```
   android/app/src/dev/google-services.json
   android/app/src/test/google-services.json
   android/app/src/uat/google-services.json
   android/app/src/prod/google-services.json
   ```

#### iOS App (Optional)

1. Click "Add app" → iOS
2. Bundle IDs:
   - Dev: `com.f2c.app.dev`
   - Test: `com.f2c.app.test`
   - UAT: `com.f2c.app.uat`
   - Prod: `com.f2c.app`
3. Download `GoogleService-Info.plist`
4. Add to Xcode project

### Step 4: Generate Firebase Options

Login to Firebase CLI:

```bash
firebase login
```

Generate configuration for each environment:

```bash
# Development
flutterfire configure \
  --project=f2c-dev \
  --out=lib/core/config/firebase/firebase_options_dev.dart \
  --platforms=android,ios

# Testing
flutterfire configure \
  --project=f2c-test \
  --out=lib/core/config/firebase/firebase_options_test.dart \
  --platforms=android,ios

# UAT
flutterfire configure \
  --project=f2c-uat \
  --out=lib/core/config/firebase/firebase_options_uat.dart \
  --platforms=android,ios

# Production
flutterfire configure \
  --project=f2c-prod \
  --out=lib/core/config/firebase/firebase_options_prod.dart \
  --platforms=android,ios
```

### Step 5: Deploy Security Rules

For each environment:

```bash
# Development
firebase use f2c-dev
firebase deploy --only firestore:rules
firebase deploy --only storage

# Testing
firebase use f2c-test
firebase deploy --only firestore:rules
firebase deploy --only storage

# UAT
firebase use f2c-uat
firebase deploy --only firestore:rules
firebase deploy --only storage

# Production
firebase use f2c-prod
firebase deploy --only firestore:rules
firebase deploy --only storage
```

---

## Code Generation

Generate Freezed and JSON serialization code:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This will generate:
- `*.freezed.dart` files
- `*.g.dart` files

**Note:** Run this command whenever you modify models.

---

## Running the Application

### Development Environment

```bash
flutter run --flavor dev -t lib/main_dev.dart
```

### Testing Environment

```bash
flutter run --flavor test -t lib/main_test.dart
```

### UAT Environment

```bash
flutter run --flavor uat -t lib/main_uat.dart
```

### Production Environment

```bash
flutter run --flavor prod -t lib/main_prod.dart
```

### Select Device

If multiple devices are connected:

```bash
flutter devices
flutter run --flavor dev -t lib/main_dev.dart -d <device-id>
```

---

## Creating Admin User

After Firebase is configured, create the initial admin user:

### Development

```bash
dart run scripts/create_admin.dart \
  --username admin \
  --email admin@f2c-dev.com \
  --password "Admin@Dev123" \
  --name "Admin User" \
  --mobile "1234567890" \
  --environment dev
```

### Testing

```bash
dart run scripts/create_admin.dart \
  --username admin \
  --email admin@f2c-test.com \
  --password "Admin@Test123" \
  --name "Admin User" \
  --mobile "1234567890" \
  --environment test
```

### UAT

```bash
dart run scripts/create_admin.dart \
  --username admin \
  --email admin@f2c-uat.com \
  --password "Admin@UAT123" \
  --name "Admin User" \
  --mobile "1234567890" \
  --environment uat
```

### Production

```bash
dart run scripts/create_admin.dart \
  --username admin \
  --email admin@f2c.com \
  --password "STRONG_PASSWORD_HERE" \
  --name "System Administrator" \
  --mobile "9876543210" \
  --environment prod
```

**IMPORTANT:**
- Use a **strong, unique password** for production
- Store credentials securely
- Change password immediately after first login

---

## Testing

### Run All Tests

```bash
flutter test
```

### Run Specific Test

```bash
flutter test test/features/authentication/models/user_model_test.dart
```

### Run Tests with Coverage

```bash
flutter test --coverage
```

### View Coverage Report

```bash
# Install lcov (macOS)
brew install lcov

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open in browser
open coverage/html/index.html
```

---

## Troubleshooting

### Issue: Firebase initialization fails

**Solution:**
- Verify Firebase configuration files exist
- Check internet connection
- Ensure Firebase project IDs match

### Issue: Build fails with "google-services.json not found"

**Solution:**
- Download `google-services.json` from Firebase Console
- Place in correct flavor folder:
  ```
  android/app/src/<flavor>/google-services.json
  ```

### Issue: Code generation fails

**Solution:**
```bash
flutter clean
flutter pub get
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

### Issue: "Seeder says admin already exists"

**Solution:**
- Check Firestore `system/configuration` document
- If you need to recreate admin, manually delete:
  - Firebase Auth user
  - Firestore user document
  - System configuration document

### Issue: Login fails with "Invalid credentials"

**Solution:**
- Verify admin user was created successfully
- Check username is lowercase
- Ensure password meets requirements
- Check Firebase Authentication is enabled

### Issue: Permission denied errors

**Solution:**
- Verify Firestore security rules are deployed
- Check user has correct role in Firestore
- Ensure user is active and not deleted

### Issue: App crashes on startup

**Solution:**
- Check logs: `flutter logs`
- Verify all dependencies are installed
- Run `flutter clean` and rebuild
- Check Firebase configuration

---

## Next Steps

After successful setup:

1. **Login** with admin credentials
2. **Change password** (required on first login)
3. **Create additional users** from admin panel
4. **Test role-based access** with different user roles
5. **Explore features** and dashboards

---

## Quick Reference

### Common Commands

```bash
# Get dependencies
flutter pub get

# Generate code
flutter pub run build_runner build --delete-conflicting-outputs

# Run dev
flutter run --flavor dev -t lib/main_dev.dart

# Build release APK
flutter build apk --flavor prod -t lib/main_prod.dart --release

# Run tests
flutter test

# Clean build
flutter clean
```

### Firebase Commands

```bash
# Login
firebase login

# Select project
firebase use <project-id>

# Deploy rules
firebase deploy --only firestore:rules
firebase deploy --only storage
```

### Useful Flutter Commands

```bash
# Check Flutter installation
flutter doctor

# List devices
flutter devices

# Analyze code
flutter analyze

# Format code
dart format .
```

---

## Support

If you encounter issues:

1. Check this guide thoroughly
2. Review `DEPLOYMENT.md` for deployment-specific issues
3. Check `ARCHITECTURE.md` for architectural questions
4. Review Firebase Console for backend issues
5. Check application logs

---

## Security Reminders

- ✅ Never commit Firebase configuration files with real credentials
- ✅ Use strong passwords for production
- ✅ Enable 2FA on Firebase Console
- ✅ Regularly review security rules
- ✅ Monitor authentication logs
- ✅ Keep dependencies updated

---

**Congratulations!** Your F2C application is now set up and ready for development! 🎉
