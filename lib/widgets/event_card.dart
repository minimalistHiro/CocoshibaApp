import 'package:flutter/material.dart';

import '../models/calendar_event.dart';

class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.imageAspectRatio = 1,
    this.imageCacheWidth,
    this.imageCacheHeight,
  });

  final CalendarEvent event;
  final VoidCallback? onTap;
  final double imageAspectRatio;
  final int? imageCacheWidth;
  final int? imageCacheHeight;

  String _formatDate(DateTime dateTime) {
    final year = dateTime.year;
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '$year/$month/$day';
  }

  String _formatTimeRange(CalendarEvent event) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final start =
        '${twoDigits(event.startDateTime.hour)}:${twoDigits(event.startDateTime.minute)}';
    final end =
        '${twoDigits(event.endDateTime.hour)}:${twoDigits(event.endDateTime.minute)}';
    return '$start〜$end';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = event.imageUrls.isNotEmpty;
    final organizerLabel =
        event.organizer.isNotEmpty ? event.organizer : '主催者情報なし';
    const borderRadius = BorderRadius.all(Radius.circular(20));

    Widget buildImage() {
      if (!hasImage) {
        return Container(
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: const Icon(
            Icons.image_not_supported_outlined,
            size: 48,
            color: Colors.black38,
          ),
        );
      }
      return Image.network(
        event.imageUrls.first,
        fit: BoxFit.cover,
        cacheWidth: imageCacheWidth,
        cacheHeight: imageCacheHeight,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade200,
            alignment: Alignment.center,
            child: const Icon(
              Icons.image_not_supported_outlined,
              size: 48,
              color: Colors.black38,
            ),
          );
        },
      );
    }

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: imageAspectRatio,
              child: buildImage(),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDate(event.startDateTime)}  ${_formatTimeRange(event)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    organizerLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
