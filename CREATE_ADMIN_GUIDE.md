# 🔐 Create Default Admin Account

## Admin Credentials
- **Email:** hi@avail404.com
- **Password:** Avail96981
- **Username:** admin

---

## ⚡ Quick Method: Firebase Console (Recommended)

Since the Dart script has compilation issues, the fastest way is to use Firebase Console directly:

### Step 1: Enable Firebase Services

1. **Enable Authentication:**
   - Go to: https://console.firebase.google.com/project/f2c-dev-ddd82/authentication/providers
   - Click "Get Started"
   - Enable "Email/Password" provider
   - Click "Save"

2. **Enable Firestore:**
   - Go to: https://console.firebase.google.com/project/f2c-dev-ddd82/firestore
   - Click "Create database"
   - Select "Production mode"
   - Choose location (preferably closest to you)
   - Click "Enable"

3. **Enable Storage:**
   - Go to: https://console.firebase.google.com/project/f2c-dev-ddd82/storage
   - Click "Get started"
   - Click "Next"
   - Choose same location as Firestore
   - Click "Done"

### Step 2: Create Admin User in Firebase Console

1. **Create Authentication User:**
   - Go to: https://console.firebase.google.com/project/f2c-dev-ddd82/authentication/users
   - Click "Add user"
   - Email: `hi@avail404.com`
   - Password: `Avail96981`
   - Click "Add user"
   - **Copy the User UID** (you'll need it for next step)

2. **Create Firestore User Document:**
   - Go to: https://console.firebase.google.com/project/f2c-dev-ddd82/firestore/data
   - Click "Start collection"
   - Collection ID: `users`
   - Click "Next"
   - Document ID: Click "Auto-ID"
   - Add the following fields:

   | Field | Type | Value |
   |-------|------|-------|
   | name | string | Admin User |
   | username | string | admin |
   | email | string | hi@avail404.com |
   | mobile | string | 0000000000 |
   | role | string | admin |
   | branchId | null | null |
   | hubId | null | null |
   | profileImage | null | null |
   | isActive | boolean | true |
   | isDeleted | boolean | false |
   | passwordChanged | boolean | false |
   | lastLogin | null | null |
   | createdAt | timestamp | (click "Set to current time") |
   | updatedAt | timestamp | (click "Set to current time") |
   | createdBy | string | Manual |
   | updatedBy | string | Manual |

   - Click "Save"

3. **Create System Configuration:**
   - In Firestore, click "Start collection"
   - Collection ID: `system`
   - Document ID: `configuration`
   - Add fields:

   | Field | Type | Value |
   |-------|------|-------|
   | initialized | boolean | true |
   | initializedAt | timestamp | (current time) |
   | initializedBy | string | Manual |
   | version | string | 1.0.0 |
   | environment | string | dev |

   - Click "Save"

---

## 🔄 Alternative Method: Node.js Script

If you prefer automation, use the Node.js script:

### Prerequisites
- Node.js installed
- Firebase Admin SDK credentials

### Steps

1. **Install Dependencies:**
   ```bash
   cd scripts
   npm install
   ```

2. **Set up Firebase Admin Credentials:**
   
   You need to authenticate with Firebase. Choose one option:

   **Option A: Application Default Credentials (Recommended)**
   ```bash
   # Install Google Cloud SDK if not already installed
   # Then login:
   gcloud auth application-default login
   ```

   **Option B: Service Account Key**
   - Go to: https://console.firebase.google.com/project/f2c-dev-ddd82/settings/serviceaccounts/adminsdk
   - Click "Generate new private key"
   - Save the JSON file as `serviceAccountKey.json` in the scripts folder
   - Update `create_admin_simple.js` to use the service account:
   ```javascript
   const serviceAccount = require('./serviceAccountKey.json');
   admin.initializeApp({
     credential: admin.credential.cert(serviceAccount),
   });
   ```

3. **Run the Script:**
   ```bash
   node create_admin_simple.js
   ```

---

## ✅ Verify Admin Account

After creating the admin account:

1. **Hot restart your Flutter app:**
   - Press `R` in the terminal where the app is running

2. **Login with credentials:**
   - Username: `admin`
   - Email: `hi@avail404.com`
   - Password: `Avail96981`

3. **Expected behavior:**
   - App should load past the loading screen
   - Login page should appear
   - You should be able to login successfully

---

## 🔍 Troubleshooting

### Issue: "System already initialized"
- An admin user already exists
- Check Firebase Console → Authentication → Users
- Check Firestore → system → configuration document

### Issue: "Email already in use"
- The email is already registered
- Delete the existing user from Firebase Console → Authentication
- Try again

### Issue: Script fails with authentication error
- Make sure Firebase services are enabled (Authentication, Firestore, Storage)
- Check your Firebase Admin credentials
- Verify you're using the correct project ID

### Issue: App still shows loading screen
- Make sure you hot restarted the app (press `R`)
- Check browser console for errors
- Verify Firebase services are enabled
- Check that Firestore rules allow read/write access

---

## 📝 Security Notes

1. **Change Password:** You'll be required to change the password on first login
2. **Secure Credentials:** Keep these credentials secure
3. **Production:** Use different credentials for production environment
4. **Firestore Rules:** Update security rules before deploying to production

---

## 🎯 Next Steps

After creating the admin account:

1. ✅ Hot restart the app
2. ✅ Login with admin credentials
3. ✅ Change password on first login
4. ✅ Set up additional users through the UI
5. ✅ Configure branches and hubs
6. ✅ Update Firestore security rules for production

---

## 📚 Related Documentation

- `SHAREDPREFERENCES_PROVIDER_FIX.md` - Loading screen fix
- `QUICK_START_WEB.md` - Web app setup guide
- `FIREBASE_SETUP_COMMANDS.md` - Firebase configuration
- `SETUP_GUIDE.md` - Complete setup guide
