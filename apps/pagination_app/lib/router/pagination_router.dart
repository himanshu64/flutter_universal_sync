import 'package:flutter/material.dart';

import '../entities/post.dart';
import '../view/post_detail_view.dart';

/// VIPER Router — owns navigation, keeping the View free of route wiring.
class PaginationRouter {
  void openDetail(BuildContext context, Post post) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PostDetailView(post: post)),
    );
  }
}
