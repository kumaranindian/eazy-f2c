import 'package:cloud_firestore/cloud_firestore.dart';

/// Run this script to fix parent schedules that have parentScheduleId set incorrectly.
/// This will set parentScheduleId to null for schedules where parentScheduleId == id.
void main() async {
  final firestore = FirebaseFirestore.instance;

  print('Fetching all operational schedules...');
  final snapshot = await firestore.collection('operational_schedules').get();

  print('Found ${snapshot.docs.length} schedules');

  int fixedCount = 0;
  for (final doc in snapshot.docs) {
    final data = doc.data();
    final id = doc.id;
    final parentScheduleId = data['parentScheduleId'] as String?;

    // If parentScheduleId matches the document ID, this is a parent schedule
    // with incorrect data - it should have parentScheduleId as null
    if (parentScheduleId != null && parentScheduleId == id) {
      print('Fixing parent schedule: $id');
      await doc.reference.update({'parentScheduleId': null});
      fixedCount++;
    }
  }

  print('Fixed $fixedCount parent schedules');
  print('Done!');
}
