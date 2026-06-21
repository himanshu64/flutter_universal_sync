import 'package:flutter/material.dart';

import '../viewmodels/timeline_viewmodel.dart';
import 'tweet_tile.dart';

/// The View — binds to the [TimelineViewModel] and renders. No business logic.
class TimelineView extends StatelessWidget {
  const TimelineView({super.key, required this.viewModel});
  final TimelineViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Timeline · MVVM'),
            bottom: viewModel.syncing
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(2),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                : null,
          ),
          body: viewModel.loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: viewModel.refresh,
                  child: viewModel.tweets.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 160),
                            Center(child: Text('Pull to load the timeline.')),
                          ],
                        )
                      : ListView.separated(
                          itemCount: viewModel.tweets.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) =>
                              TweetTile(tweet: viewModel.tweets[i]),
                        ),
                ),
        );
      },
    );
  }
}
