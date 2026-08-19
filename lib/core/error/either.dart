import 'package:test_y_app/core/error/failure.dart';

sealed class Either<L, R> {
  const Either();

  bool get isLeft => this is Left<L, R>;
  bool get isRight => this is Right<L, R>;

  T fold<T>(T Function(L left) onLeft, T Function(R right) onRight) {
    return switch (this) {
      Left<L, R>(:final value) => onLeft(value),
      Right<L, R>(:final value) => onRight(value),
    };
  }

  Either<L, T> map<T>(T Function(R right) fn) {
    return switch (this) {
      Left<L, R>(:final value) => Left(value),
      Right<L, R>(:final value) => Right(fn(value)),
    };
  }

  R? get rightOrNull => switch (this) {
        Left<L, R>() => null,
        Right<L, R>(:final value) => value,
      };

  L? get leftOrNull => switch (this) {
        Left<L, R>(:final value) => value,
        Right<L, R>() => null,
      };
}

final class Left<L, R> extends Either<L, R> {
  const Left(this.value);
  final L value;
}

final class Right<L, R> extends Either<L, R> {
  const Right(this.value);
  final R value;
}

extension EitherExtension<R> on Either<Failure, R> {
  R getOrElse(R Function() orElse) {
    return switch (this) {
      Left<Failure, R>() => orElse(),
      Right<Failure, R>(:final value) => value,
    };
  }
}
