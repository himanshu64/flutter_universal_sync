import 'package:flutter/material.dart';

import '../presenter/pagination_presenter.dart';

/// VIPER View — renders presenter state and reports the "near the end" intent
/// for infinite scroll. `ListView.builder` only builds visible rows, so memory
/// and frame cost stay flat no matter how many pages load.
class PaginationView extends StatefulWidget {
  const PaginationView({super.key, required this.presenter});
  final PaginationPresenter presenter;

  @override
  State<PaginationView> createState() => _PaginationViewState();
}

class _PaginationViewState extends State<PaginationView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      widget.presenter.loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.presenter;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        if (p.initialLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Pagination · VIPER')),
          body: ListView.builder(
            controller: _scroll,
            itemCount: p.posts.length + (p.hasMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i >= p.posts.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final post = p.posts[i];
              return ListTile(
                leading: CircleAvatar(child: Text(post.id)),
                title: Text(post.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(post.body,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => p.openDetail(context, post),
              );
            },
          ),
        );
      },
    );
  }
}
