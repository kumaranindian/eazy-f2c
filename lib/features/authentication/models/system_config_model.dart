import 'package:freezed_annotation/freezed_annotation.dart';

part 'system_config_model.freezed.dart';
part 'system_config_model.g.dart';

@freezed
class SystemConfigModel with _$SystemConfigModel {
  const factory SystemConfigModel({
    @Default(false) bool initialized,
    DateTime? initializedAt,
    String? initializedBy,
    required String version,
    required String environment,
    Map<String, dynamic>? settings,
  }) = _SystemConfigModel;

  factory SystemConfigModel.fromJson(Map<String, dynamic> json) =>
      _$SystemConfigModelFromJson(json);

  const SystemConfigModel._();

  bool get isInitialized => initialized && initializedAt != null;
}
