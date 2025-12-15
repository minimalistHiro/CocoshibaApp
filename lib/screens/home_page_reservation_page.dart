import 'package:flutter/material.dart';

import '../models/home_page_content.dart';
import '../services/firebase_auth_service.dart';
import '../services/home_page_reservation_service.dart';
import '../services/notification_service.dart';
import 'home_page_reservation_complete_page.dart';

class HomePageReservationPage extends StatefulWidget {
  const HomePageReservationPage({super.key, required this.content});

  final HomePageContent content;

  @override
  State<HomePageReservationPage> createState() =>
      _HomePageReservationPageState();
}

class _HomePageReservationPageState extends State<HomePageReservationPage> {
  late DateTime _selectedDate;
  final FirebaseAuthService _authService = FirebaseAuthService();
  final HomePageReservationService _reservationService =
      HomePageReservationService();
  final NotificationService _notificationService = NotificationService();
  bool _isSaving = false;
  int _quantity = 1;
  static const int _maxQuantity = 10;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  Future<void> _handleConfirm() async {
    if (_isSaving) return;
    final pickupLabel = _formatDate(_selectedDate);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('確認'),
            content: Text('$pickupLabel に受け取ります。よろしいですか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('受け取る'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    await _confirmReservation();
  }

  Future<void> _confirmReservation() async {
    final user = _authService.currentUser;
    final messenger = ScaffoldMessenger.of(context);
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('予約するにはログインしてください')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final completionDate = DateTime.now();
      await _reservationService.createReservation(
        contentId: widget.content.id,
        contentTitle: widget.content.title,
        userId: user.uid,
        pickupDate: _selectedDate,
        quantity: _quantity,
      );
      final pickupLabel = _formatDate(_selectedDate);
      final completionLabel = _formatDate(completionDate);
      await _notificationService.createPersonalNotification(
        userId: user.uid,
        title: '予約が完了しました',
        body:
            '${widget.content.title} の予約を受け付けました。\n受け取り日: $pickupLabel\n予約完了日: $completionLabel\n個数: $_quantity',
        category: '予約',
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomePageReservationCompletePage(
            contentTitle: widget.content.title,
            completionDate: completionDate,
            pickupDate: _selectedDate,
            quantity: _quantity,
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('予約の保存に失敗しました。もう一度お試しください')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.content.title}の予約'),
      ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
              '受け取り日を選択してください',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
              child: CalendarDatePicker(
                initialDate: _selectedDate,
                firstDate: DateTime(now.year, now.month, now.day),
                lastDate: DateTime(now.year + 1),
                onDateChanged: (date) {
                  setState(() => _selectedDate = date);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '個数',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 16),
              DropdownButton<int>(
                value: _quantity,
                items: List.generate(
                  _maxQuantity,
                  (index) => index + 1,
                )
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _quantity = value);
                },
              ),
            ],
          ),
            const SizedBox(height: 16),
            Center(
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _handleConfirm,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_isSaving ? '送信中...' : 'この日で受け取る'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${date.year}/${twoDigits(date.month)}/${twoDigits(date.day)}';
  }
}
