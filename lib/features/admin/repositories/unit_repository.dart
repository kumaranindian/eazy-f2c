import 'package:f2c/features/admin/datasources/unit_datasource.dart';
import 'package:f2c/features/admin/models/unit_model.dart';
import 'package:f2c/features/authentication/models/user_role.dart';

abstract class UnitRepository {
  Future<List<UnitModel>> getUnits();
  Stream<List<UnitModel>> watchUnits();
  Future<UnitModel> getUnitById(String id);
  Future<UnitModel> createUnit(UnitModel unit);
  Future<UnitModel> updateUnit(String id, UnitModel unit);
  Future<void> deleteUnit(String id, String userId, UserRole role);
  Future<Map<String, int>> getUnitStats();
}

class UnitRepositoryImpl implements UnitRepository {
  final UnitDataSource dataSource;

  UnitRepositoryImpl({required this.dataSource});

  @override
  Future<List<UnitModel>> getUnits() {
    return dataSource.getUnits();
  }

  @override
  Stream<List<UnitModel>> watchUnits() {
    return dataSource.watchUnits();
  }

  @override
  Future<UnitModel> getUnitById(String id) {
    return dataSource.getUnitById(id);
  }

  @override
  Future<UnitModel> createUnit(UnitModel unit) {
    return dataSource.createUnit(unit);
  }

  @override
  Future<UnitModel> updateUnit(String id, UnitModel unit) {
    return dataSource.updateUnit(id, unit);
  }

  @override
  Future<void> deleteUnit(String id, String userId, UserRole role) {
    return dataSource.deleteUnit(id);
  }

  @override
  Future<Map<String, int>> getUnitStats() async {
    final units = await getUnits();
    return {
      'total': units.length,
      'active': units.where((u) => u.isActive).length,
      'grocery': units.where((u) => u.category == 'grocery').length,
      'meat': units.where((u) => u.category == 'meat').length,
    };
  }
}
