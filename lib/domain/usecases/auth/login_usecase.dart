import 'package:test_y_app/core/error/either.dart';
import 'package:test_y_app/core/error/failure.dart';
import 'package:test_y_app/data/models/auth/auth_session.dart';
import 'package:test_y_app/domain/repositories/auth_repository.dart';

class LoginUseCase {
  LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, AuthSession>> call({
    required String credentials,
    required String password,
  }) async {
    try {
      final session = await _repository.login(
        credentials: credentials,
        password: password,
      );
      return Right(session);
    } catch (e) {
      return Left(Failure(message: e.toString()));
    }
  }
}
