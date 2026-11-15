import 'package:flutter_test/flutter_test.dart';
import 'package:sportfield_booking/data/account_repository.dart';
import 'package:sportfield_booking/data/account_service.dart';
import 'package:sportfield_booking/data/mock_store.dart';
import 'package:sportfield_booking/models/user.dart';
import 'package:sqflite/sqflite.dart';

void useMockAccounts() {
  final previous = AccountService.repository;
  AccountService.repository = _MockAccountRepository();
  addTearDown(() => AccountService.repository = previous);
}

class _UnusedDatabase extends Fake implements Database {}

class _MockAccountRepository extends AccountRepository {
  _MockAccountRepository() : super(_UnusedDatabase());

  @override
  Future<List<AppUser>> allUsers() async => List.of(MockStore.users);

  @override
  Future<AppUser?> login(String email, String password) async =>
      MockStore.login(email, password);

  @override
  Future<void> register(AppUser user) async {
    if (MockStore.emailExists(user.email)) {
      throw ArgumentError('Email đã được sử dụng');
    }
    MockStore.addUser(
      AppUser(
        id: 'test-user-${MockStore.users.length}',
        name: user.name,
        email: user.email,
        phone: user.phone,
        password: user.password,
        role: user.role,
      ),
    );
  }

  @override
  Future<void> logout() async => MockStore.logout();
}
