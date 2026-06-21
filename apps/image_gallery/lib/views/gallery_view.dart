import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../viewmodels/gallery_viewmodel.dart';
import 'photo_view.dart';

/// The grid. Battery/memory wins layered here:
/// - `GridView.builder` builds only on-screen cells (100 images, ~9 alive).
/// - `cached_network_image` keeps a memory + disk cache, so scrolling back or
///   reopening the app costs no network and no re-decode.
/// - `memCacheWidth` decodes each image at cell resolution, not full size.
class GalleryView extends StatelessWidget {
  const GalleryView({super.key, required this.viewModel});
  final GalleryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Gallery · 100 cached images'),
            actions: [
              if (viewModel.syncing)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                IconButton(
                    onPressed: viewModel.refresh,
                    icon: const Icon(Icons.refresh)),
            ],
          ),
          body: viewModel.loading && viewModel.photos.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : GridView.builder(
                  padding: const EdgeInsets.all(4),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: viewModel.photos.length,
                  itemBuilder: (context, i) {
                    final p = viewModel.photos[i];
                    return GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => PhotoView(photo: p)),
                      ),
                      child: Hero(
                        tag: p.id,
                        child: CachedNetworkImage(
                          imageUrl: p.thumbUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 300,
                          placeholder: (_, __) =>
                              const ColoredBox(color: Colors.black12),
                          errorWidget: (_, __, ___) => const ColoredBox(
                            color: Colors.black26,
                            child: Icon(Icons.broken_image, color: Colors.white54),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
