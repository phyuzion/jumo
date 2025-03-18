import 'package:get_storage/get_storage.dart';
import '../models/blocked_number.dart';

class BlockedNumbersService {
  static const String _storageKey = 'blocked_numbers';
  final _storage = GetStorage();

  List<BlockedNumber> getBlockedNumbers() {
    final List<dynamic> jsonList = _storage.read(_storageKey) ?? [];
    return jsonList.map((json) => BlockedNumber.fromJson(json)).toList();
  }

  Future<void> addBlockedNumber(String number) async {
    final blockedNumbers = getBlockedNumbers();
    blockedNumbers.add(
      BlockedNumber(number: number, blockedAt: DateTime.now()),
    );
    await _saveBlockedNumbers(blockedNumbers);
  }

  Future<void> removeBlockedNumber(String number) async {
    final blockedNumbers = getBlockedNumbers();
    blockedNumbers.removeWhere((blocked) => blocked.number == number);
    await _saveBlockedNumbers(blockedNumbers);
  }

  Future<void> _saveBlockedNumbers(List<BlockedNumber> numbers) async {
    final jsonList = numbers.map((number) => number.toJson()).toList();
    await _storage.write(_storageKey, jsonList);
  }

  bool isNumberBlocked(String number) {
    return getBlockedNumbers().any((blocked) => blocked.number == number);
  }
}
