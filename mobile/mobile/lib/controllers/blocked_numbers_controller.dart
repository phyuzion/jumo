import 'package:get_storage/get_storage.dart';
import 'package:mobile/graphql/block_api.dart';
import '../models/blocked_number.dart';

class BlockedNumbersController {
  static const String _storageKey = 'blocked_numbers';
  final _storage = GetStorage();

  List<BlockedNumber> getBlockedNumbers() {
    final List<dynamic> jsonList = _storage.read(_storageKey) ?? [];
    return jsonList.map((json) => BlockedNumber.fromJson(json)).toList();
  }

  Future<void> addBlockedNumber(String number) async {
    try {
      final blockedNumbers = getBlockedNumbers();
      blockedNumbers.add(BlockedNumber(number: number));

      // 서버에 전체 목록 업데이트
      final serverNumbers = await BlockApi.updateBlockedNumbers(
        blockedNumbers.map((bn) => bn.number).toList(),
      );

      // 로컬 저장소 업데이트
      await _saveBlockedNumbers(
        serverNumbers.map((n) => BlockedNumber(number: n)).toList(),
      );
    } catch (e) {
      // 서버 오류 시 로컬에만 저장
      final blockedNumbers = getBlockedNumbers();
      blockedNumbers.add(BlockedNumber(number: number));
      await _saveBlockedNumbers(blockedNumbers);
      rethrow;
    }
  }

  Future<void> removeBlockedNumber(String number) async {
    try {
      final blockedNumbers = getBlockedNumbers();
      blockedNumbers.removeWhere((blocked) => blocked.number == number);

      // 서버에 전체 목록 업데이트
      final serverNumbers = await BlockApi.updateBlockedNumbers(
        blockedNumbers.map((bn) => bn.number).toList(),
      );

      // 로컬 저장소 업데이트
      await _saveBlockedNumbers(
        serverNumbers.map((n) => BlockedNumber(number: n)).toList(),
      );
    } catch (e) {
      // 서버 오류 시 로컬에서만 제거
      final blockedNumbers = getBlockedNumbers();
      blockedNumbers.removeWhere((blocked) => blocked.number == number);
      await _saveBlockedNumbers(blockedNumbers);
      rethrow;
    }
  }

  Future<void> _saveBlockedNumbers(List<BlockedNumber> numbers) async {
    final jsonList = numbers.map((number) => number.toJson()).toList();
    await _storage.write(_storageKey, jsonList);
  }

  bool isNumberBlocked(String number) {
    return getBlockedNumbers().any((blocked) => blocked.number == number);
  }
}
