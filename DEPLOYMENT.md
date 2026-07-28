# F2C Deployment Guide

This guide provides step-by-step instructions for deploying the F2C application across all environments.

## Prerequisites

- Flutter SDK >= 3.0.0
- Firebase CLI installed and configured
- Access to Firebase projects (f2c-dev, f2c-test, f2c-uat, f2c-prod)
- Android Studio / Xcode for mobile builds
- Git for version control

## Environment Setup

### 1. Firebase Projects Setup

Create four Firebase projects:

```
f2c-dev       (Development)
f2c-test      (Testing)
f2c-uat       (UAT)
f2c-prod      (Production)
```

For each project:

1. Enable Authentication (Email/Password)
2. Create Firestore Database
3. Enable Firebase Storage
4. Enable Cloud Messaging (optional)

### 2. Firebase Configuration

#### Install Firebase CLI

```bash
npm install -g firebase-tools
firebase login
```

#### Generate Firebase Options

For each environment, run:

```bash
# Development
flutterfire configure --project=f2c-dev --out=lib/core/config/firebase/firebase_options_dev.dart

# Testing
flutterfire configure --project=f2c-test --out=lib/core/config/firebase/firebase_options_test.dart

# UAT
flutterfire configure --project=f2c-uat --out=lib/core/config/firebase/firebase_options_uat.dart

# Production
flutterfire configure --project=f2c-prod --out=lib/core/config/firebase/firebase_options_prod.dart
```

### 3. Install Dependencies

```bash
flutter pub get
cd scripts && flutter pub get && cd ..
```

### 4. Generate Code

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Firestore Security Rules Deployment

Deploy security rules for each environment:

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

## Create Admin User

For each environment, create the initial admin user:

```bash
# Development
dart run scripts/create_admin.dart \
  --username admin \
  --email admin@f2c-dev.com \
  --password "Admin@Dev123" \
  --name "Admin User" \
  --environment dev

# Testing
dart run scripts/create_admin.dart \
  --username admin \
  --email admin@f2c-test.com \
  --password "Admin@Test123" \
  --name "Admin User" \
  --environment test

# UAT
dart run scripts/create_admin.dart \
  --username admin \
  --email admin@f2c-uat.com \
  --password "Admin@UAT123" \
  --name "Admin User" \
  --environment uat

# Production
dart run scripts/create_admin.dart \
  --username admin \
  --email admin@f2c.com \
  --password "SECURE_PASSWORD_HERE" \
  --name "System Administrator" \
  --environment prod
```

**IMPORTANT:** 
- Use strong, unique passwords for production
- Store credentials securely
- Change password immediately after first login

## Android Build Configuration

### Update `android/app/build.gradle`

```gradle
android {
    defaultConfig {
        applicationId "com.f2c.app"
        minSdkVersion 21
        targetSdkVersion 33
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }

    flavorDimensions "environment"
    
    productFlavors {
        dev {
            dimension "environment"
            applicationIdSuffix ".dev"
            resValue "string", "app_name", "F2C Dev"
        }
        test {
            dimension "environment"
            applicationIdSuffix ".test"
            resValue "string", "app_name", "F2C Test"
        }
        uat {
            dimension "environment"
            applicationIdSuffix ".uat"
            resValue "string", "app_name", "F2C UAT"
        }
        prod {
            dimension "environment"
            resValue "string", "app_name", "F2C"
        }
    }

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

### Download google-services.json

For each flavor, download the appropriate `google-services.json`:

```
android/app/src/dev/google-services.json
android/app/src/test/google-services.json
android/app/src/uat/google-services.json
android/app/src/prod/google-services.json
```

## iOS Build Configuration

### Update `ios/Runner/Info.plist`

Add flavor-specific configurations.

### Download GoogleService-Info.plist

For each flavor, download and configure the appropriate `GoogleService-Info.plist`.

## Building the Application

### Development

```bash
# Android
flutter build apk --flavor dev -t lib/main_dev.dart

# iOS
flutter build ios --flavor dev -t lib/main_dev.dart
```

### Testing

```bash
# Android
flutter build apk --flavor test -t lib/main_test.dart

# iOS
flutter build ios --flavor test -t lib/main_test.dart
```

### UAT

```bash
# Android
flutter build apk --flavor uat -t lib/main_uat.dart

# iOS
flutter build ios --flavor uat -t lib/main_uat.dart
```

### Production

```bash
# Android (Release)
flutter build appbundle --flavor prod -t lib/main_prod.dart --release

# iOS (Release)
flutter build ipa --flavor prod -t lib/main_prod.dart --release
```

## Running Tests

```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/
```

## Continuous Integration / Continuous Deployment

### GitHub Actions Example

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy F2C

on:
  push:
    branches: [main, develop]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Run tests
        run: flutter test
      
      - name: Build APK
        run: flutter build apk --flavor prod -t lib/main_prod.dart
```

## Post-Deployment Checklist

- [ ] Verify Firebase Authentication is enabled
- [ ] Verify Firestore security rules are deployed
- [ ] Verify Storage security rules are deployed
- [ ] Admin user created successfully
- [ ] Test login with admin credentials
- [ ] Verify password change on first login
- [ ] Test user creation from admin panel
- [ ] Verify role-based access control
- [ ] Test audit logging
- [ ] Verify session management
- [ ] Test logout functionality
- [ ] Monitor Firebase usage and quotas

## Monitoring

### Firebase Console

Monitor the following in Firebase Console:

- Authentication users
- Firestore usage
- Storage usage
- Cloud Functions (if applicable)
- Performance metrics

### Error Tracking

Consider integrating:

- Firebase Crashlytics
- Sentry
- Custom error logging

## Backup Strategy

### Firestore Backup

Set up automated Firestore backups:

```bash
gcloud firestore export gs://[BUCKET_NAME]
```

### User Data Export

Regularly export user data for compliance and backup purposes.

## Security Best Practices

1. **Never commit sensitive data** to version control
2. **Use environment variables** for API keys
3. **Enable 2FA** for Firebase console access
4. **Regularly review** Firestore security rules
5. **Monitor** authentication logs for suspicious activity
6. **Rotate passwords** periodically
7. **Implement** rate limiting on sensitive operations
8. **Use HTTPS** for all network communications

## Troubleshooting

### Common Issues

**Issue:** Firebase initialization fails
- **Solution:** Verify Firebase configuration files are correct for the environment

**Issue:** Login fails with "user not found"
- **Solution:** Ensure admin user was created using the seeder script

**Issue:** Permission denied errors
- **Solution:** Check Firestore security rules are deployed correctly

**Issue:** Build fails with flavor errors
- **Solution:** Verify flavor configuration in build.gradle

## Support

For issues or questions:
- Check documentation in `/docs`
- Review Firebase logs
- Contact development team

## Version History

- **v1.0.0** - Initial production release
  - Multi-environment support
  - Role-based authentication
  - User management
  - Audit logging
