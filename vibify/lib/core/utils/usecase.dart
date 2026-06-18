abstract class UseCase<R, Params> {
  Future<R> call(Params params);
}

abstract class UseCaseNoParams<R> {
  Future<R> call();
}

class NoParams {
  const NoParams();
}
