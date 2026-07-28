# Firebase Setup - Quick Commands

## 🔥 Enable Firebase Services (Web Console)

### 1. Authentication
```
1. Go to: https://console.firebase.google.com/project/f2c-dev-ddd82/authentication
2. Click "Get Started"
3. Click "Email/Password"
4. Toggle "Enable"
5. Click "Save"
```

### 2. Firestore Database
```
1. Go to: https://console.firebase.google.com/project/f2c-dev-ddd82/firestore
2. Click "Create database"
3. Select "Start in production mode"
4. Choose location (e.g., asia-south1)
5. Click "Enable"
```

### 3. Storage
```
1. Go to: https://console.firebase.google.com/project/f2c-dev-ddd82/storage
2. Click "Get started"
3. Click "Next"
4. Choose same location as Firestore
5. Click "Done"
```

---

## 💻 Deploy Security Rules (Terminal)

```bash
# Set Firebase project
firebase use f2c-dev-ddd82

# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Storage rules
firebase deploy --only storage
```

---

## 👤 Create Admin User (Terminal)

```bash
# Install script dependencies
cd scripts
flutter pub get
cd ..

# Create admin user
dart run scripts/create_admin.dart \
  --username admin \
  --email admin@f2c.com \
  --password "Admin@123" \
  --name "Admin User" \
  --environment dev
```

**Save these credentials:**
- Username: `admin`
- Password: `Admin@123`

---

## 🌐 Run the App

```bash
# Development
flutter run -d chrome -t lib/main_dev.dart

# Build for production
flutter build web -t lib/main_dev.dart
```

---

## ✅ Verification Checklist

- [ ] Authentication enabled in Firebase Console
- [ ] Firestore Database created
- [ ] Storage enabled
- [ ] Firestore rules deployed
- [ ] Storage rules deployed
- [ ] Admin user created
- [ ] App running in Chrome
- [ ] Can login with admin credentials

---

## 🔗 Quick Links

- **Firebase Console:** https://console.firebase.google.com/project/f2c-dev-ddd82
- **Authentication:** https://console.firebase.google.com/project/f2c-dev-ddd82/authentication
- **Firestore:** https://console.firebase.google.com/project/f2c-dev-ddd82/firestore
- **Storage:** https://console.firebase.google.com/project/f2c-dev-ddd82/storage
- **Hosting:** https://console.firebase.google.com/project/f2c-dev-ddd82/hosting

---

## 📝 Notes

- The app is already running in Chrome
- Complete the Firebase setup steps above
- Then login with admin credentials
- You'll be prompted to change password on first login
