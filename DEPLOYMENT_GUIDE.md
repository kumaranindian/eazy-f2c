# F2C Multi-Environment Deployment Guide

## 📋 Overview

The F2C application supports 4 separate environments, each with its own Firebase project:

| Environment | Firebase Project | Main File | Deployment Script |
|-------------|-----------------|-----------|-------------------|
| **Development** | f2c-dev-ddd82 | `main_dev.dart` | `deploy_dev.bat` |
| **Test** | f2c-test | `main_test.dart` | `deploy_test.bat` |
| **UAT** | f2c-uat | `main_uat.dart` | `deploy_uat.bat` |
| **Production** | f2c-prod | `main_prod.dart` | `deploy_prod.bat` |

---

## 🚀 Quick Deployment

### Deploy to Development
```bash
cd scripts
deploy_dev.bat
```

### Deploy to Test
```bash
cd scripts
deploy_test.bat
```

### Deploy to UAT
```bash
cd scripts
deploy_uat.bat
```

### Deploy to Production
```bash
cd scripts
deploy_prod.bat
```

---

## 🔧 Manual Deployment Steps

### 1. Build for Specific Environment

**Development:**
```bash
flutter build web --release -t lib/main_dev.dart
```

**Test:**
```bash
flutter build web --release -t lib/main_test.dart
```

**UAT:**
```bash
flutter build web --release -t lib/main_uat.dart
```

**Production:**
```bash
flutter build web --release -t lib/main_prod.dart
```

### 2. Switch Firebase Project

```bash
# For Development
firebase use f2c-dev-ddd82

# For Test
firebase use f2c-test

# For UAT
firebase use f2c-uat

# For Production
firebase use f2c-prod
```

### 3. Deploy to Firebase Hosting

```bash
firebase deploy --only hosting
```

### 4. Deploy Firestore Rules and Indexes

```bash
# Deploy both rules and indexes together
firebase deploy --only firestore

# Or deploy separately
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

**Note:** The automated deployment scripts (`deploy_*.bat`) automatically deploy both Firestore rules and indexes as the final step.

---

## 🏃 Running Locally

### Development Environment
```bash
flutter run -d chrome -t lib/main_dev.dart
```

### Test Environment
```bash
flutter run -d chrome -t lib/main_test.dart
```

### UAT Environment
```bash
flutter run -d chrome -t lib/main_uat.dart
```

### Production Environment
```bash
flutter run -d chrome -t lib/main_prod.dart
```

---

## 🔐 Firebase Project Configuration

### Development (f2c-dev-ddd82)
- **Project ID:** f2c-dev-ddd82
- **Hosting URL:** https://f2c-dev-ddd82.web.app
- **Config File:** `lib/core/config/firebase/firebase_options_dev.dart`

### Test (f2c-test)
- **Project ID:** f2c-test
- **Hosting URL:** https://f2c-test.web.app
- **Config File:** `lib/core/config/firebase/firebase_options_test.dart`

### UAT (f2c-uat)
- **Project ID:** f2c-uat
- **Hosting URL:** https://f2c-uat.web.app
- **Config File:** `lib/core/config/firebase/firebase_options_uat.dart`

### Production (f2c-prod)
- **Project ID:** f2c-prod
- **Hosting URL:** https://f2c-prod.web.app
- **Config File:** `lib/core/config/firebase/firebase_options_prod.dart`

---

## 📝 Pre-Deployment Checklist

Before deploying to any environment:

- [ ] All tests passing
- [ ] Code reviewed and approved
- [ ] Firebase configuration updated
- [ ] Firestore indexes created
- [ ] Security rules reviewed
- [ ] Environment variables set correctly
- [ ] Build completes without errors

### Additional Checks for Production:
- [ ] UAT testing completed
- [ ] Stakeholder approval received
- [ ] Backup of current production data
- [ ] Rollback plan prepared
- [ ] Monitoring and alerts configured

---

## 🔄 Environment Promotion Flow

```
Development → Test → UAT → Production
```

1. **Development**: Daily development and testing
2. **Test**: QA and integration testing
3. **UAT**: User acceptance testing with stakeholders
4. **Production**: Live environment for end users

---

## 🛠️ Troubleshooting

### Build Fails
```bash
# Clean build cache
flutter clean
flutter pub get
flutter build web --release -t lib/main_[env].dart
```

### Firebase Project Not Found
```bash
# List available projects
firebase projects:list

# Add project alias
firebase use --add
```

### Deployment Fails
```bash
# Check Firebase login
firebase login

# Verify project access
firebase projects:list

# Check deployment status
firebase hosting:channel:list
```

---

## 📞 Support

For deployment issues or questions:
- Check Firebase Console: https://console.firebase.google.com
- Review deployment logs
- Contact DevOps team

---

## 🔒 Security Notes

- Never commit Firebase API keys to public repositories
- Use environment-specific service accounts
- Rotate credentials regularly
- Monitor Firebase usage and billing
- Review security rules before production deployment

---

Last Updated: July 29, 2026
