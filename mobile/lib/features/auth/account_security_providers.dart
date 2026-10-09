import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import 'data/repositories/account_security_repository_impl.dart';
import 'domain/repositories/account_security_repository.dart';

final accountSecurityProvider = Provider<AccountSecurityRepository>(
  (ref) => AccountSecurityRepositoryImpl(ref.watch(dioProvider)),
);
