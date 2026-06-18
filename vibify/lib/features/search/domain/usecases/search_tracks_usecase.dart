import '../entities/search_result.dart';
import '../repositories/search_repository.dart';
import '../../../../core/utils/usecase.dart';

class SearchTracksUsecase implements UseCase<SearchResult, String> {
  final SearchRepository _repository;

  SearchTracksUsecase(this._repository);

  @override
  Future<SearchResult> call(String query) => _repository.search(query);
}
