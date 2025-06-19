import 'dart:developer';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/services/native_methods.dart';
import 'package:mobile/utils/constants.dart';

/// 디바이스 정보 및 폴더블 기기 관련 유틸리티
class DeviceUtils {
  // 싱글톤 패턴
  static final DeviceUtils _instance = DeviceUtils._internal();
  factory DeviceUtils() => _instance;
  DeviceUtils._internal();

  // 디바이스 정보 캐시
  String? _model;
  String? _manufacturer;
  bool? _isFlip;
  bool? _isFold;
  bool? _isOpen;

  /// 디바이스 모델명
  Future<String> getModel() async {
    if (_model != null) return _model!;

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        _model = androidInfo.model;
        _manufacturer = androidInfo.manufacturer;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _model = iosInfo.model;
        _manufacturer = iosInfo.name;
      }
    } catch (e) {
      log('디바이스 모델 정보 확인 중 오류: $e');
      _model = 'Unknown';
    }

    return _model ?? 'Unknown';
  }

  /// 제조사명
  Future<String> getManufacturer() async {
    if (_manufacturer != null) return _manufacturer!;
    await getModel(); // 모델 정보를 가져오는 과정에서 제조사 정보도 설정됨
    return _manufacturer ?? 'Unknown';
  }

  /// 갤럭시 플립 기기인지 확인
  Future<bool> isFlip() async {
    if (_isFlip != null) return _isFlip!;

    final model = await getModel();
    final manufacturer = await getManufacturer();

    // 삼성 기기이고 모델명이 플립 모델 목록에 포함되어 있는지 확인
    _isFlip =
        manufacturer.toLowerCase() == 'samsung' &&
        FLIP_MODELS.any((flipModel) => model.contains(flipModel));

    return _isFlip!;
  }

  /// 갤럭시 폴드 기기인지 확인
  Future<bool> isFold() async {
    if (_isFold != null) return _isFold!;

    final model = await getModel();
    final manufacturer = await getManufacturer();

    // 삼성 기기이고 모델명이 폴드 모델 목록에 포함되어 있는지 확인
    _isFold =
        manufacturer.toLowerCase() == 'samsung' &&
        FOLD_MODELS.any((foldModel) => model.contains(foldModel));

    return _isFold!;
  }

  /// 폴더블 기기인지 확인 (플립 또는 폴드)
  Future<bool> isFoldable() async {
    return await isFlip() || await isFold();
  }

  /// 일반 기기인지 확인 (폴더블이 아닌 기기)
  Future<bool> isNormal() async {
    return !(await isFoldable());
  }

  /// 디바이스가 열려 있는지 확인 (폴더블 기기만 해당)
  Future<bool> isOpen() async {
    // 폴더블 기기가 아니면 항상 열려 있는 것으로 간주
    if (!(await isFoldable())) return true;

    try {
      // 네이티브 메서드로 디바이스 상태 확인
      final state = await NativeMethods.getDeviceState();
      _isOpen = state['isOpen'] ?? true;
      return _isOpen!;
    } catch (e) {
      log('디바이스 열림 상태 확인 중 오류: $e');
      return true; // 오류 발생 시 기본값은 열려 있는 상태
    }
  }

  /// 현재 디스플레이 ID 확인
  Future<int> getCurrentDisplayId() async {
    try {
      final state = await NativeMethods.getDeviceState();
      return state['currentDisplayId'] ?? 0;
    } catch (e) {
      log('디스플레이 ID 확인 중 오류: $e');
      return 0; // 오류 발생 시 기본값은 메인 디스플레이(0)
    }
  }

  /// 커버 디스플레이에 표시 중인지 확인
  Future<bool> isOnCoverDisplay() async {
    final displayId = await getCurrentDisplayId();
    return displayId == 1;
  }

  /// 캐시 초기화
  void clearCache() {
    _model = null;
    _manufacturer = null;
    _isFlip = null;
    _isFold = null;
    _isOpen = null;
  }
}
