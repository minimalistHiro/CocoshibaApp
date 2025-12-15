import 'package:flutter/material.dart';

import '../models/calendar_event.dart';

class EventListCard extends StatelessWidget {
  const EventListCard({
    super.key,
    required this.event,
    this.onTap,
    this.isInterested = false,
    this.isReserved = false,
    this.isFavorite = false,
    this.statusLabel,
    this.showInterestButton = true,
    this.showFavoriteButton = false,
    this.canShowFavoriteButton = true,
    this.onToggleInterest,
    this.onToggleFavorite,
  });

  final CalendarEvent event;
  final VoidCallback? onTap;
  final bool isInterested;
  final bool isReserved;
  final bool isFavorite;
  final String? statusLabel;
  final bool showInterestButton;
  final bool showFavoriteButton;
  final bool canShowFavoriteButton;
  final VoidCallback? onToggleInterest;
  final VoidCallback? onToggleFavorite;

  String _formatDate(DateTime dateTime) {
    final y = dateTime.year;
    final m = dateTime.month.toString().padLeft(2, '0');
    final d = dateTime.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
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
    final showFavorite = showFavoriteButton && canShowFavoriteButton;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EventThumbnail(
              imageUrl:
                  event.imageUrls.isNotEmpty ? event.imageUrls.first : null,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatDate(event.startDateTime)}  ${_formatTimeRange(event)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey.shade600),
                            ),
                            if (event.organizer.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  event.organizer,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey.shade600),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (showInterestButton)
                        _InterestButton(
                          isInterested: isInterested,
                          onPressed: onToggleInterest,
                        ),
                      if (showFavorite)
                        _FavoriteButton(
                          isFavorite: isFavorite,
                          onPressed: onToggleFavorite,
                        ),
                    ],
                  ),
                  if (statusLabel != null || isReserved)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          if (isReserved)
                            _StatusChip(
                              label: statusLabel ?? '予約済み',
                              color: Colors.green.shade600,
                            ),
                          if (statusLabel != null && !isReserved)
                            _StatusChip(
                              label: statusLabel!,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
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

class _EventThumbnail extends StatelessWidget {
  const _EventThumbnail({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      height: 160,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Icon(Icons.event, color: Colors.grey.shade500, size: 48),
    );
    if (imageUrl == null || imageUrl!.isEmpty) return placeholder;
    return SizedBox(
      height: 160,
      child: Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _InterestButton extends StatelessWidget {
  const _InterestButton({
    required this.isInterested,
    required this.onPressed,
  });

  final bool isInterested;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = isInterested ? Colors.pinkAccent : Colors.grey.shade500;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(
            isInterested ? Icons.favorite : Icons.favorite_border,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({
    required this.isFavorite,
    required this.onPressed,
  });

  final bool isFavorite;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = isFavorite ? Colors.amber.shade600 : Colors.grey.shade500;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(
            isFavorite ? Icons.star : Icons.star_border,
            color: color,
          ),
        ),
      ],
    );
  }
}
