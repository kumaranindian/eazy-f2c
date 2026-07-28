# F2C Web App - Quick Start Guide

Get your F2C Flutter Web Application running in minutes!

---

## ⚡ Quick Setup (5 Minutes)

### 1. Install Dependencies

```bash
flutter pub get
cd scripts && flutter pub get && cd ..
```

### 2. Generate Code

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Configure Firebase (Web)

```bash
# Login to Firebase
firebase login

# Configure for web
flutterfire configure --project=f2c-dev --out=lib/core/config/firebase/firebase_options_dev.dart --platforms=web
```

### 4. Run the App

```bash
flutter run -d chrome -t lib/main_dev.dart
```

**That's it!** Your app should open in Chrome.

---

## 🔥 Firebase Web Setup

### Enable Firebase Services

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (f2c-dev)
3. Enable these services:

**Authentication:**
- Click "Authentication" → "Get Started"
- Enable "Email/Password" sign-in method

**Firestore:**
- Click "Firestore Database" → "Create database"
- Start in **production mode**
- Choose your region

**Storage:**
- Click "Storage" → "Get started"
- Start in **production mode**

### Deploy Security Rules

```bash
firebase use f2c-dev
firebase deploy --only firestore:rules
firebase deploy --only storage
```

---

## 👤 Create Admin User

```bash
dart run scripts/create_admin.dart \
  --username admin \
  --email admin@f2c.com \
  --password "Admin@123" \
  --name "Admin User" \
  --environment dev
```

**Save these credentials!** You'll need them to login.

---

## 🚀 First Login

1. Open the app in your browser
2. Login with:
   - **Username:** `admin`
   - **Password:** `Admin@123`
3. You'll be prompted to change your password
4. Set a new secure password
5. You're in! 🎉

---

## 🌐 Running on Different Browsers

### Chrome (Default)
```bash
flutter run -d chrome -t lib/main_dev.dart
```

### Edge
```bash
flutter run -d edge -t lib/main_dev.dart
```

### Web Server (Any Browser)
```bash
flutter run -d web-server -t lib/main_dev.dart
```

Then open: `http://localhost:PORT` in any browser

---

## 🏗️ Build for Production

```bash
# Build
flutter build web -t lib/main_prod.dart --release

# Output is in: build/web/
```

---

## 🚢 Deploy to Firebase Hosting

```bash
# Initialize hosting (first time only)
firebase init hosting

# Build and deploy
flutter build web -t lib/main_prod.dart --release
firebase deploy --only hosting
```

Your app will be live at: `https://YOUR-PROJECT.web.app`

---

## 📱 Access Your Web App

### Development URLs

After deployment, your app will be available at:

- **Dev:** `https://f2c-dev.web.app`
- **Test:** `https://f2c-test.web.app`
- **UAT:** `https://f2c-uat.web.app`
- **Prod:** `https://f2c-prod.web.app`

Or custom domains if configured.

---

## 🔧 Common Commands

### Development
```bash
# Run
flutter run -d chrome -t lib/main_dev.dart

# Build
flutter build web -t lib/main_dev.dart

# Deploy
firebase use f2c-dev && firebase deploy --only hosting
```

### Production
```bash
# Run
flutter run -d chrome -t lib/main_prod.dart

# Build
flutter build web -t lib/main_prod.dart --release

# Deploy
firebase use f2c-prod && firebase deploy --only hosting
```

---

## 🐛 Troubleshooting

### App doesn't load in browser

**Check:**
1. Firebase configuration is correct
2. Run `flutter doctor` to verify setup
3. Check browser console for errors

### Firebase initialization fails

**Solution:**
```bash
# Reconfigure Firebase
flutterfire configure --project=f2c-dev --platforms=web
```

### Build errors

**Solution:**
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### Can't login

**Check:**
1. Admin user was created successfully
2. Firebase Authentication is enabled
3. Username is lowercase
4. Password meets requirements

---

## 📚 Next Steps

1. ✅ Login with admin credentials
2. ✅ Change password
3. ✅ Create test users
4. ✅ Explore dashboards
5. ✅ Test role-based access
6. ✅ Deploy to production

---

## 🎯 Key Features to Test

### As Admin
- Create users with different roles
- Edit user information
- Activate/Deactivate users
- Reset passwords
- View all dashboards

### As Customer
- Login with customer credentials
- View customer dashboard
- Limited access (can't see admin features)

### As Packaging/Delivery
- Login with respective credentials
- See role-specific dashboards

---

## 🌟 Pro Tips

### Clean URLs
The app uses clean URLs (no `#` in routes) thanks to `url_strategy` package.

### Responsive Design
The app works on all screen sizes - try resizing your browser!

### Environment Badges
Non-production environments show an environment badge for easy identification.

### Session Management
- "Remember Me" keeps you logged in
- Auto-logout after 30 minutes of inactivity
- Token auto-refresh every 25 minutes

---

## 📞 Need Help?

Check these resources:
- `README.md` - Full documentation
- `SETUP_GUIDE.md` - Detailed setup
- `WEB_DEPLOYMENT.md` - Web deployment guide
- `ARCHITECTURE.md` - Architecture details

---

## ✅ Verification Checklist

- [ ] Flutter SDK installed
- [ ] Dependencies installed (`flutter pub get`)
- [ ] Code generated (build_runner)
- [ ] Firebase project created
- [ ] Firebase configured for web
- [ ] Security rules deployed
- [ ] Admin user created
- [ ] App runs in browser
- [ ] Can login successfully
- [ ] Password change works
- [ ] Dashboards load correctly

---

**Congratulations! Your F2C Web App is running! 🎉**

Access it at: `http://localhost:PORT` or your deployed URL.

---

**Happy Coding! 🚀**
