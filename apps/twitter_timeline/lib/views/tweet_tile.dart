import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/tweet.dart';

/// A single timeline row. The avatar is loaded through `cached_network_image`
/// (memory + disk cache) and downsampled via [CachedNetworkImage.memCacheWidth]
/// so we never decode a full-size bitmap for a 44px circle — a real battery
/// and memory win on long, image-heavy feeds.
class TweetTile extends StatelessWidget {
  const TweetTile({super.key, required this.tweet});
  final Tweet tweet;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: CachedNetworkImage(
              imageUrl: tweet.avatarUrl,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              memCacheWidth: 88,
              placeholder: (_, __) =>
                  const SizedBox(width: 44, height: 44, child: ColoredBox(color: Colors.black12)),
              errorWidget: (_, __, ___) =>
                  const CircleAvatar(radius: 22, child: Icon(Icons.person)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(tweet.author,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(tweet.handle,
                          style: TextStyle(color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(tweet.text),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
