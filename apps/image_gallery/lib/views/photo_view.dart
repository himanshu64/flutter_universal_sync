import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/photo.dart';

/// Full-screen, pinch-zoomable image. The full-resolution variant is cached
/// independently of the thumbnail, so reopening it is instant.
class PhotoView extends StatelessWidget {
  const PhotoView({super.key, required this.photo});
  final Photo photo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(photo.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: Hero(
          tag: photo.id,
          child: InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: photo.fullUrl,
              fit: BoxFit.contain,
              placeholder: (_, __) => const CircularProgressIndicator(),
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.broken_image, color: Colors.white54, size: 64),
            ),
          ),
        ),
      ),
    );
  }
}
