import 'package:flutter/material.dart';

import '../models/home_page_content.dart';
import '../services/firebase_auth_service.dart';
import '../services/home_page_reservation_service.dart';
import '../services/notification_service.dart';

class HomePageReservationPage extends StatefulWidget {
  const HomePageReservationPage({super.key, required this.content});

  final HomePageContent content;

  @override
  State<HomePageReservationPage> createState() =>
      _HomePageReservationPageState();
}

class _HomePageReservationPageState extends State<HomePageReservationPage> {
  late DateTime _selectedDate;
  DateTime? _pickupDate;
  late final TextEditingController _pickupDateController;
  final FirebaseAuthService _authService = FirebaseAuthService();
  final HomePageReservationService _reservationService =
      HomePageReservationService();
  final NotificationService _notificationService = NotificationService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _pickupDateController = TextEditingController();
  }

  @override
  void dispose() {
    _pickupDateController.dispose();
    super.dispose();
  }

  Future<void> _pickPickupDate() async {
    final now = DateTime.now();
    final initial = _pickupDate ?? _selectedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() {
        _pickupDate = picked;
        _pickupDateController.text = _formatDate(picked);
      });
    }
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

    if (_pickupDate == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('受け取り日を選択してください')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _reservationService.createReservation(
        contentId: widget.content.id,
        contentTitle: widget.content.title,
        reservedDate: _selectedDate,
        userId: user.uid,
        pickupDate: _pickupDate,
      );
      final reservedLabel = _formatDate(_selectedDate);
      final pickupLabel = _formatDate(_pickupDate!);
      await _notificationService.createNotification(
        title: '予約が完了しました',
        body:
            '${widget.content.title} の予約を受け付けました。\n予約日: $reservedLabel\n受け取り日: $pickupLabel',
        category: '予約',
        targetUserId: user.uid,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('予約を受け付けました')),
      );
      Navigator.of(context).pop();
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
              'ご希望の日付を選択してください',
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
        const SizedBox(height: 16),
        TextField(
          controller: _pickupDateController,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: '受け取り日',
            hintText: '受け取り日を選択してください',
            suffixIcon: Icon(Icons.calendar_today),
          ),
          onTap: _pickPickupDate,
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _confirmReservation,
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
                label: Text(_isSaving ? '送信中...' : 'この日で予約する'),
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
