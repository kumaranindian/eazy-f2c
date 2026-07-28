const admin = require('firebase-admin');

const serviceAccount = {
  projectId: 'f2c-dev-ddd82',
};

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: serviceAccount.projectId,
});

const auth = admin.auth();
const firestore = admin.firestore();

async function createAdmin() {
  const username = 'admin';
  const email = 'hi@avail404.com';
  const password = 'Avail96981';
  const name = 'Admin User';
  const mobile = '0000000000';
  const environment = 'dev';

  console.log('═══════════════════════════════════════════════════════════');
  console.log('F2C Admin User Creator');
  console.log('═══════════════════════════════════════════════════════════');
  console.log(`Environment: ${environment}`);
  console.log(`Username: ${username}`);
  console.log(`Email: ${email}`);
  console.log(`Name: ${name}`);
  console.log('═══════════════════════════════════════════════════════════');
  console.log('');

  try {
    console.log('Checking system configuration...');
    const systemDoc = await firestore.collection('system').doc('configuration').get();

    if (systemDoc.exists) {
      const data = systemDoc.data();
      if (data.initialized) {
        console.log('✗ System already initialized');
        console.log('✗ Admin user already exists');
        console.log('');
        console.log('If you need to create another admin, use the application UI.');
        process.exit(1);
      }
    }
    console.log('✓ System not initialized');

    console.log('');
    console.log('Checking for existing admin users...');
    const adminQuery = await firestore
      .collection('users')
      .where('role', '==', 'admin')
      .limit(1)
      .get();

    if (!adminQuery.empty) {
      console.log('✗ Admin user already exists');
      process.exit(1);
    }
    console.log('✓ No admin users found');

    console.log('');
    console.log('Creating Firebase Authentication user...');
    let userRecord;
    try {
      userRecord = await auth.createUser({
        email: email,
        password: password,
        displayName: name,
      });
      console.log(`✓ Firebase Auth user created: ${userRecord.uid}`);
    } catch (error) {
      console.log(`✗ Failed to create Firebase Auth user: ${error.message}`);
      process.exit(1);
    }

    console.log('');
    console.log('Creating Firestore user document...');
    try {
      const userData = {
        name: name,
        username: username.toLowerCase(),
        email: email,
        mobile: mobile,
        role: 'admin',
        branchId: null,
        hubId: null,
        profileImage: null,
        isActive: true,
        isDeleted: false,
        passwordChanged: false,
        lastLogin: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: 'Seeder',
        updatedBy: 'Seeder',
      };

      const docRef = await firestore.collection('users').add(userData);
      console.log(`✓ Firestore user document created: ${docRef.id}`);
    } catch (error) {
      console.log(`✗ Failed to create Firestore user document: ${error.message}`);
      
      if (userRecord) {
        console.log('Cleaning up Firebase Auth user...');
        await auth.deleteUser(userRecord.uid);
      }
      process.exit(1);
    }

    console.log('');
    console.log('Creating system configuration...');
    try {
      await firestore.collection('system').doc('configuration').set({
        initialized: true,
        initializedAt: admin.firestore.FieldValue.serverTimestamp(),
        initializedBy: 'Seeder',
        version: '1.0.0',
        environment: environment,
      });
      console.log('✓ System configuration created');
    } catch (error) {
      console.log(`✗ Failed to create system configuration: ${error.message}`);
    }

    console.log('');
    console.log('Creating initial audit log...');
    try {
      await firestore.collection('auditLogs').add({
        id: Date.now().toString(),
        action: 'userCreated',
        performedBy: 'Seeder',
        performedFor: userRecord.uid,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        device: 'Seeder Script',
        ipAddress: null,
        environment: environment,
        metadata: {
          username: username,
          role: 'admin',
          email: email,
        },
        description: 'Initial admin user created by seeder',
      });
      console.log('✓ Audit log created');
    } catch (error) {
      console.log(`Warning: Failed to create audit log: ${error.message}`);
    }

    console.log('');
    console.log('═══════════════════════════════════════════════════════════');
    console.log('✓ SUCCESS: Admin user created successfully!');
    console.log('═══════════════════════════════════════════════════════════');
    console.log('');
    console.log('Login Credentials:');
    console.log(`  Username: ${username}`);
    console.log(`  Email: ${email}`);
    console.log(`  Password: ${password}`);
    console.log('');
    console.log('IMPORTANT:');
    console.log('  - You will be required to change your password on first login');
    console.log('  - Keep these credentials secure');
    console.log('  - Delete this output after saving credentials');
    console.log('');
    console.log('═══════════════════════════════════════════════════════════');

    process.exit(0);
  } catch (error) {
    console.log('');
    console.log(`✗ Error: ${error.message}`);
    console.error(error);
    process.exit(1);
  }
}

createAdmin();
