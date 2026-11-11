import '../models/user.dart';
import 'account_repository.dart';
import 'mock_store.dart';

/// Keeps existing screens compatible while account storage uses SQLite.
class AccountService {
  AccountService._();
  static AccountRepository? repository;

  static AccountRepository get _requiredRepository {
    final value = repository;
    if (value == null) {
      throw StateError('Dữ liệu tài khoản chưa được khởi tạo.');
    }
    return value;
  }

  static Future<void> initialize() async {
    repository = await AccountRepository.open(seed: List.of(MockStore.users));
    await _refresh();
    MockStore.currentUser = await repository!.restoreSession();
  }

  static Future<void> _refresh() async {
    final users = await repository!.allUsers();
    MockStore.users
      ..clear()
      ..addAll(users);
  }

  static Future<AppUser?> login(String email, String password) async {
    final user = await _requiredRepository.login(email, password);
    if (user != null) MockStore.currentUser = user;
    return user;
  }

  static Future<void> register(AppUser user) async {
    await _requiredRepository.register(user);
    await _refresh();
  }

  static Future<void> logout() async {
    await _requiredRepository.logout();
    MockStore.logout();
  }

  static Future<AppUser?> updateProfile({
    required String userId,
    required String name,
    required String phone,
    required String? avatarPath,
  }) async {
    if (MockStore.currentUser?.id != userId) return null;
    final updated = await _requiredRepository.updateProfile(
      userId: userId,
      name: name,
      phone: phone,
      avatarPath: avatarPath,
    );
    if (updated != null) {
      final index = MockStore.users.indexWhere((u) => u.id == userId);
      if (index >= 0) MockStore.users[index] = updated;
      if (MockStore.currentUser?.id == userId) MockStore.currentUser = updated;
    }
    return updated;
  }
}
