import 'package:equatable/equatable.dart';
import 'package:secure_payment_portal/core/error/failure.dart';

/// The outcome of an operation that can fail in an expected way. Expected
/// errors are values, never exceptions thrown across layers.
sealed class Result<T> {
  const Result();

  /// Collapses both cases into one value.
  R fold<R>(R Function(T value) onSuccess, R Function(Failure failure) onErr) {
    return switch (this) {
      Success<T>(:final value) => onSuccess(value),
      Err<T>(:final failure) => onErr(failure),
    };
  }

  Result<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success<T>(:final value) => Success<R>(transform(value)),
      Err<T>(:final failure) => Err<R>(failure),
    };
  }

  T? get valueOrNull => switch (this) {
    Success<T>(:final value) => value,
    Err<T>() => null,
  };

  Failure? get failureOrNull => switch (this) {
    Success<T>() => null,
    Err<T>(:final failure) => failure,
  };

  bool get isSuccess => this is Success<T>;
}

final class Success<T> extends Result<T> with Equatable {
  const Success(this.value);

  /// Success of an operation with nothing to return.
  static const Success<void> unit = Success<void>(null);

  final T value;

  @override
  List<Object?> get props => [value];
}

final class Err<T> extends Result<T> with Equatable {
  const Err(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
