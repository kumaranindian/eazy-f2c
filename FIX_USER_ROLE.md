# 🔧 Fix User Role Issue

## ❌ **Problem:**
You have an existing user in Firebase Authentication, but either:
1. The user document doesn't exist in Firestore, OR
2. The user has the old `'admin'` role instead of `'super_admin'`

## ✅ **Solution:**

### **Option 1: Delete Everything and Start Fresh (Recommended)**

1. **Go to Firebase Console:**
   - Visit: https://console.firebase.google.com/project/f2c-dev-ddd82

2. **Delete Authentication User:**
   - Click **Authentication** in left sidebar
   - Click **Users** tab
   - Find the user (hi@avail404.com)
   - Click the **3 dots** menu → **Delete account**
   - Confirm deletion

3. **Delete Firestore User Document:**
   - Click **Firestore Database** in left sidebar
   - Navigate to **users** collection
   - Find and delete any user documents
   - Also delete the **system** collection → **configuration** document

4. **Restart Your App:**
   - The app will detect no users exist
   - You'll be redirected to First User Setup
   - Create new user - will be **super_admin**

---

### **Option 2: Update Existing User to Super Admin**

If you want to keep the existing user, update their role in Firestore:

1. **Go to Firebase Console:**
   - Visit: https://console.firebase.google.com/project/f2c-dev-ddd82

2. **Find User in Firestore:**
   - Click **Firestore Database**
   - Navigate to **users** collection
   - Find your user document

3. **Update the Role Field:**
   - Click on the user document
   - Find the `role` field
   - Change value from `admin` to `super_admin`
   - Click **Update**

4. **Verify passwordChanged Field:**
   - While you're there, check `passwordChanged` field
   - Should be `true` (boolean)
   - If it's `false`, change it to `true`

5. **Refresh Your App:**
   - Reload the browser
   - Try logging in again

---

### **Option 3: Manual Firestore Document Creation**

If the user document doesn't exist at all in Firestore:

1. **Get User ID from Authentication:**
   - Firebase Console → Authentication → Users
   - Copy the **User UID** (looks like: `abc123xyz456...`)

2. **Create Firestore Document:**
   - Firebase Console → Firestore Database
   - Navigate to **users** collection
   - Click **Add document**
   - **Document ID:** Paste the User UID from step 1
   - Add these fields:

```javascript
{
  "name": "Your Name",
  "username": "karthic",
  "email": "hi@avail404.com",
  "mobile": "0000000000",
  "role": "super_admin",           // ← Important!
  "branchId": null,
  "hubId": null,
  "profileImage": null,
  "isActive": true,
  "isDeleted": false,
  "passwordChanged": true,          // ← Important!
  "lastLogin": null,
  "createdAt": [Timestamp] now,
  "updatedAt": [Timestamp] now,
  "createdBy": "Manual Setup",
  "updatedBy": "Manual Setup"
}
```

3. **Save and Refresh App**

---

## 🎯 **Recommended Steps:**

**I recommend Option 1 (Delete and Start Fresh)** because:
- ✅ Clean slate
- ✅ Ensures proper super_admin setup
- ✅ No data inconsistencies
- ✅ Tests the first user setup flow

**Steps:**
1. Go to Firebase Console: https://console.firebase.google.com/project/f2c-dev-ddd82
2. Delete user from **Authentication**
3. Delete documents from **Firestore** (users and system collections)
4. Refresh your app
5. Go through First User Setup
6. Login with new super_admin account

---

## 🔍 **How to Check Current State:**

### **Check Firebase Authentication:**
1. Firebase Console → Authentication → Users
2. Look for users listed
3. Note the User UID

### **Check Firestore:**
1. Firebase Console → Firestore Database
2. Check **users** collection
3. See if document exists with matching UID
4. Check the `role` field value

### **Check System Configuration:**
1. Firestore Database → **system** collection
2. Look for **configuration** document
3. If `initialized: true`, the system thinks setup is complete

---

## 📝 **Quick Fix Commands:**

If you prefer using Firebase CLI:

```bash
# List all users
firebase auth:export users.json --project f2c-dev-ddd82

# Delete all Firestore data (CAREFUL!)
# This will delete everything in Firestore
firebase firestore:delete --all-collections --project f2c-dev-ddd82

# Note: You'll need to manually delete Auth users from console
```

---

## ✅ **After Fix:**

Once you've completed the fix:

1. **Refresh the app**
2. **You should see:**
   - First User Setup page (if you deleted everything)
   - OR successful login (if you updated the role)
3. **Login credentials:**
   - Email/Username: hi@avail404.com or karthic
   - Password: Avail96981
4. **Verify:**
   - User role shows as "Super Admin"
   - Can access admin dashboard
   - Can create new users

---

## 🚨 **Important Notes:**

- **Backup First:** If you have important data, export it before deleting
- **Development Only:** These instructions are for development environment
- **Production:** Never delete production data without proper backup
- **Role Field:** Must be exactly `super_admin` (with underscore, lowercase)
- **Boolean Fields:** `isActive`, `isDeleted`, `passwordChanged` must be boolean, not string

---

## 🎯 **Expected Result:**

After fixing, you should see in Firestore:

**users/{uid}:**
```javascript
{
  "role": "super_admin",        // ← This is key!
  "passwordChanged": true,       // ← This too!
  "isActive": true,
  "isDeleted": false,
  // ... other fields
}
```

**system/configuration:**
```javascript
{
  "initialized": true,
  "initializedAt": [Timestamp],
  "initializedBy": "System Setup",
  "version": "1.0.0",
  "environment": "dev"
}
```

Good luck! 🚀
