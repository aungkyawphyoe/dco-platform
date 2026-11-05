import '../entities/shared_users_overview.dart';

abstract interface class SharedUsersRepository {
  Stream<SharedUsersOverview?> watch();
  Future<void> refresh();
}
