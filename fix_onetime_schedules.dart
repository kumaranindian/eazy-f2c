import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options_dev.dart';

/// Script to fix one-time schedules that incorrectly have a parentScheduleId
void main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;
  final schedulesRef = firestore.collection('operational_schedules');

  print('Fetching all schedules...');
  final snapshot = await schedulesRef.get();
  print('Total schedules: ${snapshot.docs.length}');

  int fixedCount = 0;
  
  for (final doc in snapshot.docs) {
    final data = doc.data();
    final recurrenceType = data['recurrenceType'] as String?;
    final parentScheduleId = data['parentScheduleId'];
    final scheduledDate = (data['scheduledDate'] as Timestamp).toDate();
    final branchName = data['branchName'] as String?;
    
    // Check if it's a one-time schedule with a parentScheduleId
    if (recurrenceType == 'ScheduleRecurrenceType.oneTime' && 
        parentScheduleId != null && 
        parentScheduleId.toString().isNotEmpty) {
      
      print('\n🔴 Found one-time schedule with parentScheduleId:');
      print('   ID: ${doc.id}');
      print('   Branch: $branchName');
      print('   Date: $scheduledDate');
      print('   Current parentScheduleId: $parentScheduleId');
      print('   Fixing...');
      
      // Fix by setting parentScheduleId to null
      await doc.reference.update({'parentScheduleId': null});
      fixedCount++;
      
      print('   ✅ Fixed!');
    }
  }
  
  print('\n' + '=' * 60);
  print('Summary:');
  print('Total schedules checked: ${snapshot.docs.length}');
  print('One-time schedules fixed: $fixedCount');
  print('=' * 60);
}
