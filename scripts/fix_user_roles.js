// Script to fix user roles from super_admin to superAdmin
// Run this with: node scripts/fix_user_roles.js

const admin = require('firebase-admin');
const serviceAccount = require('../firebase-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixUserRoles() {
  try {
    console.log('Starting to fix user roles...');
    
    // Get all users with super_admin role
    const usersSnapshot = await db.collection('users')
      .where('role', '==', 'super_admin')
      .get();
    
    if (usersSnapshot.empty) {
      console.log('No users found with super_admin role');
      return;
    }
    
    console.log(`Found ${usersSnapshot.size} user(s) with super_admin role`);
    
    // Update each user
    const batch = db.batch();
    usersSnapshot.forEach(doc => {
      console.log(`Updating user: ${doc.id} (${doc.data().email})`);
      batch.update(doc.ref, { role: 'superAdmin' });
    });
    
    await batch.commit();
    console.log('✅ Successfully updated all users!');
    
    // Verify
    const verifySnapshot = await db.collection('users')
      .where('role', '==', 'superAdmin')
      .get();
    console.log(`✅ Verification: ${verifySnapshot.size} user(s) now have superAdmin role`);
    
  } catch (error) {
    console.error('❌ Error fixing user roles:', error);
  } finally {
    process.exit();
  }
}

fixUserRoles();
