# 🚀 F2C Deployment Summary

## ✅ What Gets Deployed

Each deployment script (`deploy_*.bat`) performs the following steps automatically:

### Step 1: Build Flutter Web App
```bash
flutter build web --release -t lib/main_[environment].dart
```
- Compiles Flutter app for web
- Optimizes for production
- Outputs to `build/web/` directory

### Step 2: Deploy to Firebase Hosting
```bash
firebase use [project-id]
firebase deploy --only hosting
```
- Switches to correct Firebase project
- Uploads web app to Firebase Hosting
- Makes app live at hosting URL

### Step 3: Deploy Firestore Rules & Indexes ✨
```bash
firebase deploy --only firestore
```
**This includes:**
- ✅ **Firestore Security Rules** (`firestore.rules`)
- ✅ **Firestore Indexes** (`firestore.indexes.json`)

---

## 📦 What's Included in Each Deployment

| Component | File/Folder | Deployed To | Notes |
|-----------|-------------|-------------|-------|
| **Web App** | `build/web/` | Firebase Hosting | Your Flutter app |
| **Security Rules** | `firestore.rules` | Firestore | Access control |
| **Database Indexes** | `firestore.indexes.json` | Firestore | Query optimization |

---

## 🎯 Deployment Commands

### Quick Deploy (Recommended)

```bash
# Development
cd scripts
deploy_dev.bat

# Test
deploy_test.bat

# UAT
deploy_uat.bat

# Production
deploy_prod.bat
```

### Manual Deploy (If needed)

```bash
# 1. Build
flutter build web --release -t lib/main_prod.dart

# 2. Switch project
firebase use f2c-prod

# 3. Deploy everything
firebase deploy --only hosting,firestore
```

---

## 🔄 Deployment Flow

```
┌─────────────────────────────────────────────────────────┐
│  Step 1: Build Flutter Web                              │
│  ├─ Compile Dart to JavaScript                          │
│  ├─ Optimize assets                                     │
│  └─ Generate build/web/                                 │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  Step 2: Deploy to Firebase Hosting                     │
│  ├─ Switch to correct Firebase project                  │
│  ├─ Upload web files                                    │
│  └─ Update hosting configuration                        │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│  Step 3: Deploy Firestore Rules & Indexes               │
│  ├─ Upload firestore.rules                              │
│  ├─ Upload firestore.indexes.json                       │
│  ├─ Validate rules syntax                               │
│  └─ Create/update indexes                               │
└─────────────────────────────────────────────────────────┘
                          ↓
                    ✅ DEPLOYMENT COMPLETE!
```

---

## 📋 Deployment Checklist

Before running deployment:

- [ ] Code tested locally
- [ ] All tests passing
- [ ] Changes committed to Git
- [ ] Correct environment selected
- [ ] Firebase CLI logged in (`firebase login`)
- [ ] Firestore rules reviewed
- [ ] Indexes optimized

After deployment:

- [ ] Verify app loads at hosting URL
- [ ] Test critical user flows
- [ ] Check Firestore rules working
- [ ] Monitor for errors in Firebase Console
- [ ] Verify indexes are building

---

## 🌐 Environment URLs

After deployment, your app will be available at:

| Environment | URL |
|-------------|-----|
| **Development** | https://f2c-dev-ddd82.web.app |
| **Test** | https://f2c-test.web.app |
| **UAT** | https://f2c-uat.web.app |
| **Production** | https://f2c-prod.web.app |

---

## 🔍 Verify Deployment

### 1. Check Hosting
```bash
firebase hosting:channel:list
```

### 2. Check Firestore Rules
- Go to Firebase Console → Firestore Database → Rules
- Verify rules are updated with latest timestamp

### 3. Check Firestore Indexes
- Go to Firebase Console → Firestore Database → Indexes
- Verify all indexes show "Enabled" status

---

## 🛠️ Troubleshooting

### Build Fails
```bash
flutter clean
flutter pub get
flutter build web --release -t lib/main_[env].dart
```

### Firestore Rules Deployment Fails
```bash
# Test rules locally
firebase emulators:start --only firestore

# Validate rules
firebase firestore:rules:validate firestore.rules
```

### Indexes Not Building
- Check Firebase Console → Firestore → Indexes
- Indexes can take several minutes to build
- Status will show "Building" → "Enabled"

---

## 📞 Quick Reference

### Firebase CLI Commands
```bash
# Login
firebase login

# List projects
firebase projects:list

# Switch project
firebase use [project-id]

# Deploy specific components
firebase deploy --only hosting
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only firestore  # Rules + Indexes

# Check deployment status
firebase hosting:channel:list
```

---

## ⚠️ Important Notes

1. **Firestore Rules & Indexes are ALWAYS deployed** as part of the automated scripts
2. **Rules apply immediately** after deployment
3. **Indexes may take time to build** (check Firebase Console)
4. **Test in lower environments first** (Dev → Test → UAT → Prod)
5. **Keep firestore.rules and firestore.indexes.json in sync** across environments

---

Last Updated: July 29, 2026
