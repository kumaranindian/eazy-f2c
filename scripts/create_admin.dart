import 'dart:io';
import 'package:args/args.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('username', abbr: 'u', help: 'Admin username')
    ..addOption('email', abbr: 'e', help: 'Admin email')
    ..addOption('password', abbr: 'p', help: 'Admin password')
    ..addOption('name', abbr: 'n', help: 'Admin full name')
    ..addOption('mobile', abbr: 'm', help: 'Admin mobile number', defaultsTo: '0000000000')
    ..addOption('environment', help: 'Environment (dev/test/uat/prod)', defaultsTo: 'dev')
    ..addFlag('help', abbr: 'h', help: 'Show help', negatable: false);

  try {
    final results = parser.parse(arguments);

    if (results['help'] as bool) {
      print('F2C Admin User Seeder');
      print('');
      print('Usage: dart run scripts/create_admin.dart [options]');
      print('');
      print(parser.usage);
      exit(0);
    }

    final username = results['username'] as String?;
    final email = results['email'] as String?;
    final password = results['password'] as String?;
    final name = results['name'] as String?;
    final mobile = results['mobile'] as String;
    final environment = results['environment'] as String;

    if (username == null || email == null || password == null || name == null) {
      print('Error: username, email, password, and name are required');
      print('');
      print('Usage: dart run scripts/create_admin.dart [options]');
      print('');
      print(parser.usage);
      exit(1);
    }

    print('═══════════════════════════════════════════════════════════');
    print('F2C Admin User Seeder');
    print('═══════════════════════════════════════════════════════════');
    print('Environment: $environment');
    print('Username: $username');
    print('Email: $email');
    print('Name: $name');
    print('═══════════════════════════════════════════════════════════');
    print('');

    print('Initializing Firebase...');
    await Firebase.initializeApp(
      options: _getFirebaseOptions(environment),
    );
    print('✓ Firebase initialized');

    final firestore = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;

    print('');
    print('Checking system configuration...');
    final systemDoc = await firestore.collection('system').doc('configuration').get();

    if (systemDoc.exists) {
      final data = systemDoc.data()!;
      final initialized = data['initialized'] as bool? ?? false;

      if (initialized) {
        print('✗ System already initialized');
        print('✗ Admin user already exists');
        print('');
        print('If you need to create another admin, use the application UI.');
        exit(1);
      }
    }

    print('✓ System not initialized');

    print('');
    print('Checking for existing admin users...');
    final adminQuery = await firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .limit(1)
        .get();

    if (adminQuery.docs.isNotEmpty) {
      print('✗ Admin user already exists');
      exit(1);
    }

    print('✓ No admin users found');

    print('');
    print('Creating Firebase Authentication user...');
    UserCredential? userCredential;
    try {
      userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('✓ Firebase Auth user created: ${userCredential.user?.uid}');
    } catch (e) {
      print('✗ Failed to create Firebase Auth user: $e');
      exit(1);
    }

    print('');
    print('Creating Firestore user document...');
    try {
      final userData = {
        'name': name,
        'username': username.toLowerCase(),
        'email': email,
        'mobile': mobile,
        'role': 'admin',
        'branchId': null,
        'hubId': null,
        'profileImage': null,
        'isActive': true,
        'isDeleted': false,
        'passwordChanged': false,
        'lastLogin': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': 'Seeder',
        'updatedBy': 'Seeder',
      };

      final docRef = await firestore.collection('users').add(userData);
      print('✓ Firestore user document created: ${docRef.id}');
    } catch (e) {
      print('✗ Failed to create Firestore user document: $e');
      
      if (userCredential?.user != null) {
        print('Cleaning up Firebase Auth user...');
        await userCredential!.user!.delete();
      }
      exit(1);
    }

    print('');
    print('Creating system configuration...');
    try {
      await firestore.collection('system').doc('configuration').set({
        'initialized': true,
        'initializedAt': FieldValue.serverTimestamp(),
        'initializedBy': 'Seeder',
        'version': '1.0.0',
        'environment': environment,
      });
      print('✓ System configuration created');
    } catch (e) {
      print('✗ Failed to create system configuration: $e');
    }

    print('');
    print('Creating initial audit log...');
    try {
      await firestore.collection('auditLogs').add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'action': 'userCreated',
        'performedBy': 'Seeder',
        'performedFor': userCredential.user?.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'device': 'Seeder Script',
        'ipAddress': null,
        'environment': environment,
        'metadata': {
          'username': username,
          'role': 'admin',
          'email': email,
        },
        'description': 'Initial admin user created by seeder',
      });
      print('✓ Audit log created');
    } catch (e) {
      print('Warning: Failed to create audit log: $e');
    }

    print('');
    print('═══════════════════════════════════════════════════════════');
    print('✓ SUCCESS: Admin user created successfully!');
    print('═══════════════════════════════════════════════════════════');
    print('');
    print('Login Credentials:');
    print('  Username: $username');
    print('  Password: $password');
    print('');
    print('IMPORTANT:');
    print('  - You will be required to change your password on first login');
    print('  - Keep these credentials secure');
    print('  - Delete this output after saving credentials');
    print('');
    print('═══════════════════════════════════════════════════════════');

    exit(0);
  } catch (e) {
    print('');
    print('✗ Error: $e');
    exit(1);
  }
}

FirebaseOptions _getFirebaseOptions(String environment) {
  switch (environment) {
    case 'dev':
      return const FirebaseOptions(
        apiKey: 'AIzaSyArjT7aqptS8pH14JGuJDBnNGPh8b4Pczs',
        appId: '1:453142868625:web:7d9cd09bd8f78025d10530',
        messagingSenderId: '453142868625',
        projectId: 'f2c-dev-ddd82',
        storageBucket: 'f2c-dev-ddd82.firebasestorage.app',
      );
    case 'test':
      return const FirebaseOptions(
        apiKey: 'YOUR_TEST_API_KEY',
        appId: 'YOUR_TEST_APP_ID',
        messagingSenderId: 'YOUR_TEST_MESSAGING_SENDER_ID',
        projectId: 'f2c-test',
        storageBucket: 'f2c-test.appspot.com',
      );
    case 'uat':
      return const FirebaseOptions(
        apiKey: 'YOUR_UAT_API_KEY',
        appId: 'YOUR_UAT_APP_ID',
        messagingSenderId: 'YOUR_UAT_MESSAGING_SENDER_ID',
        projectId: 'f2c-uat',
        storageBucket: 'f2c-uat.appspot.com',
      );
    case 'prod':
      return const FirebaseOptions(
        apiKey: 'YOUR_PROD_API_KEY',
        appId: 'YOUR_PROD_APP_ID',
        messagingSenderId: 'YOUR_PROD_MESSAGING_SENDER_ID',
        projectId: 'f2c-prod',
        storageBucket: 'f2c-prod.appspot.com',
      );
    default:
      throw Exception('Invalid environment: $environment');
  }
}
