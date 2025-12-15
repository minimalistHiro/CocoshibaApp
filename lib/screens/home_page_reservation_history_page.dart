import 'package:flutter/material.dart';

import '../models/home_page_reservation_member.dart';
import '../services/home_page_reservation_service.dart';

class HomePageReservationHistoryPage extends StatelessWidget {
  HomePageReservationHistoryPage({super.key, required this.userId});

  final String userId;
  final HomePageReservationService _reservationService =
      HomePageReservationService();

  String _formatDateTime(DateTime? date) {
    if (date == null) return '';
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$year年$month月$day日 $hour:$minute';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year年$month月$day日';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('予約'),
      ),
      body: StreamBuilder<List<HomePageReservationMember>>(
        stream: _reservationService.watchUserReservations(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '予約情報を取得できませんでした',
                style: theme.textTheme.bodyLarge,
              ),
            );
          }

          final reservations = snapshot.data ?? const <HomePageReservationMember>[];
          if (reservations.isEmpty) {
            return Center(
              child: Text(
                'ホームページで予約したものがありません',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: Colors.grey.shade700),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final reservation = reservations[index];
              final pickupLabel = _formatDate(
                reservation.pickupDate ?? reservation.reservedDate,
              );
              final reservedLabel = _formatDateTime(
                reservation.createdAt ?? reservation.reservedDate,
              );
              final statusLabel = reservation.isCompleted ? '受け取り済み' : '予約中';
              final statusColor =
                  reservation.isCompleted ? Colors.grey.shade600 : Colors.green;
              final title = (reservation.contentTitle?.isNotEmpty == true)
                  ? reservation.contentTitle!
                  : (reservation.userName?.isNotEmpty == true
                      ? reservation.userName!
                      : '予約');

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
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
                                  title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              statusLabel,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (pickupLabel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _InfoRow(
                            icon: Icons.event_available_outlined,
                            label: '受け取り日',
                            value: pickupLabel,
                          ),
                        ),
                      if (reservedLabel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _InfoRow(
                            icon: Icons.schedule_outlined,
                            label: '予約日',
                            value: reservedLabel,
                          ),
                        ),
                      _InfoRow(
                        icon: Icons.shopping_bag_outlined,
                        label: '個数',
                        value: '${reservation.quantity}個',
                      ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: reservations.length,
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
