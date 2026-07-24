import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/features/admin/models/unit_model.dart';

abstract class UnitDataSource {
  Future<List<UnitModel>> getUnits();
  Stream<List<UnitModel>> watchUnits();
  Future<UnitModel> getUnitById(String id);
  Future<UnitModel> createUnit(UnitModel unit);
  Future<UnitModel> updateUnit(String id, UnitModel unit);
  Future<void> deleteUnit(String id);
}

class UnitDataSourceImpl implements UnitDataSource {
  final FirebaseFirestore firestore;

  UnitDataSourceImpl({required this.firestore});

  @override
  Future<List<UnitModel>> getUnits() async {
    final snapshot = await firestore
        .collection('units')
        .where('isDeleted', isEqualTo: false)
        .orderBy('category')
        .orderBy('name')
        .get();

    return snapshot.docs.map((doc) => UnitModel.fromFirestore(doc)).toList();
  }

  @override
  Stream<List<UnitModel>> watchUnits() {
    return firestore
        .collection('units')
        .where('isDeleted', isEqualTo: false)
        .orderBy('category')
        .orderBy('name')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UnitModel.fromFirestore(doc)).toList());
  }

  @override
  Future<UnitModel> getUnitById(String id) async {
    final doc = await firestore.collection('units').doc(id).get();
    if (!doc.exists) {
      throw Exception('Unit not found');
    }
    return UnitModel.fromFirestore(doc);
  }

  @override
  Future<UnitModel> createUnit(UnitModel unit) async {
    final docRef = await firestore.collection('units').add(unit.toFirestore());
    final doc = await docRef.get();
    return UnitModel.fromFirestore(doc);
  }

  @override
  Future<UnitModel> updateUnit(String id, UnitModel unit) async {
    await firestore.collection('units').doc(id).update(unit.toFirestore());
    final doc = await firestore.collection('units').doc(id).get();
    return UnitModel.fromFirestore(doc);
  }

  @override
  Future<void> deleteUnit(String id) async {
    await firestore.collection('units').doc(id).update({'isDeleted': true});
  }
}
