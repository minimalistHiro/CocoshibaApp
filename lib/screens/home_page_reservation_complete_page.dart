import 'package:flutter/material.dart';

class HomePageReservationCompletePage extends StatelessWidget {
  const HomePageReservationCompletePage({
    super.key,
    required this.contentTitle,
    required this.completionDate,
    required this.pickupDate,
    required this.quantity,
  });

  final String contentTitle;
  final DateTime completionDate;
  final DateTime pickupDate;
  final int quantity;

  String _formatDate(DateTime date) {
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('予約完了'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: Icon(Icons.check, size: 40, color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '予約が完了しました',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  contentTitle,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              _InfoTile(
                label: '予約完了日',
                value: _formatDate(completionDate),
                icon: Icons.event_available_outlined,
              ),
              const SizedBox(height: 12),
              _InfoTile(
                label: '受け取り日',
                value: _formatDate(pickupDate),
                icon: Icons.schedule_outlined,
              ),
              const SizedBox(height: 12),
              _InfoTile(
                label: '個数',
                value: '$quantity個',
                icon: Icons.shopping_bag_outlined,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                icon: const Icon(Icons.home_outlined),
                label: const Text('ホームに戻る'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
