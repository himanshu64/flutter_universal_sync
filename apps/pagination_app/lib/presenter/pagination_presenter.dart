import 'package:flutter/widgets.dart';

import '../entities/post.dart';
import '../interactor/pagination_interactor.dart';
import '../router/pagination_router.dart';

/// VIPER Presenter — drives the View. Holds presentation state, asks the
/// Interactor for data, and delegates navigation to the Router.
class PaginationPresenter extends ChangeNotifier {
  PaginationPresenter({required this.interactor, required this.router}) {
    _init();
  }

  final PaginationInteractor interactor;
  final PaginationRouter router;

  List<Post> posts = const [];
  bool initialLoading = true;
  bool loadingMore = false;
  String? error;

  bool get hasMore => interactor.hasMore;

  Future<void> _init() async {
    posts = await interactor.cached(); // instant, offline
    initialLoading = false;
    notifyListeners();
    await loadMore();
  }

  Future<void> loadMore() async {
    if (loadingMore || !interactor.hasMore) return;
    loadingMore = true;
    notifyListeners();
    try {
      posts = await interactor.loadNextPage();
      error = null;
    } catch (e) {
      error = '$e';
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  void openDetail(BuildContext context, Post post) =>
      router.openDetail(context, post);
}
