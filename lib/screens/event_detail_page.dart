import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import '../services/event_service.dart';
import 'edit_event_page.dart';

class EventDetailPage extends StatefulWidget {
  const EventDetailPage({super.key, required this.event});

  final CalendarEvent event;

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  late final PageController _pageController;
  int _currentIndex = 0;
  final EventService _eventService = EventService();
  late CalendarEvent _event;
  bool _isDeleting = false;
  bool _hasReservation = false;
  bool _isReservationLoading = true;
  bool _isReservationProcessing = false;
  late final Stream<int> _reservationCountStream;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _event = widget.event;
    _reservationCountStream = _eventService.watchReservationCount(_event.id);
    _loadReservationStatus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日';
  }

  String _formatTimeRange(DateTime start, DateTime end) {
    String format(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${format(start)}〜${format(end)}';
  }

  bool _isEventFull(int reservationCount) {
    final capacity = _event.capacity;
    if (capacity <= 0) return false;
    return reservationCount >= capacity;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _reservationCountStream,
      builder: (context, snapshot) {
        final event = _event;
        final theme = Theme.of(context);
        final hasImages = event.imageUrls.isNotEmpty;
        final imageHeight = MediaQuery.of(context).size.width;
        final reservationCount = snapshot.data ?? 0;
        final isEventFull = _isEventFull(reservationCount);
        final bool isEventEnded = DateTime.now().isAfter(event.endDateTime);
        final reservationCountLabel =
            snapshot.hasData ? '$reservationCount人' : '取得中...';
        final isReservationBusy =
            _isReservationLoading || _isReservationProcessing;
        final bool isReservationButtonDisabled = isEventEnded ||
            (!_hasReservation && isEventFull);
        final String reservationButtonLabel = isEventEnded
            ? 'イベントは終了しました'
            : _hasReservation
                ? '予約を解除する'
                : isEventFull
                    ? '定員に達しました'
                    : '予約する';

        return Scaffold(
          appBar: AppBar(
            title: const Text('イベント詳細'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'イベントを編集',
                onPressed: _openEditEvent,
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: imageHeight,
                        width: double.infinity,
                        child: hasImages
                            ? Stack(
                                children: [
                                  PageView.builder(
                                    controller: _pageController,
                                    onPageChanged: (index) =>
                                        setState(() => _currentIndex = index),
                                    itemCount: event.imageUrls.length,
                                    itemBuilder: (context, index) =>
                                        Image.network(
                                      event.imageUrls[index],
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                        color: Colors.grey.shade200,
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.broken_image,
                                            size: 48),
                                      ),
                                    ),
                                  ),
                                  if (event.imageUrls.length > 1)
                                    Positioned(
                                      bottom: 16,
                                      left: 0,
                                      right: 0,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: List.generate(
                                          event.imageUrls.length,
                                          (index) => Container(
                                            width: 8,
                                            height: 8,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 4),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _currentIndex == index
                                                  ? Colors.white
                                                  : Colors.white54,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : Container(
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: const Icon(Icons.event, size: 48),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.name,
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            _InfoRow(
                              label: '主催',
                              value: event.organizer.isNotEmpty
                                  ? event.organizer
                                  : '未設定',
                            ),
                            const SizedBox(height: 8),
                            _InfoRow(
                              label: '定員',
                              value: event.capacity > 0
                                  ? '${event.capacity}人'
                                  : '設定なし',
                            ),
                            const SizedBox(height: 8),
                            _InfoRow(
                              label: '日付',
                              value: _formatDate(event.startDateTime),
                            ),
                            const SizedBox(height: 8),
                            _InfoRow(
                              label: '予約人数',
                              value: reservationCountLabel,
                            ),
                            const SizedBox(height: 8),
                            _InfoRow(
                              label: '時間',
                              value: _formatTimeRange(
                                event.startDateTime,
                                event.endDateTime,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'イベント内容',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              event.content.isNotEmpty ? event.content : '記載なし',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _hasReservation
                                ? Colors.redAccent
                                : Theme.of(context).colorScheme.primary,
                            disabledBackgroundColor: Colors.grey.shade400,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed:
                              (isReservationButtonDisabled || isReservationBusy)
                                  ? null
                                  : _onReservationButtonPressed,
                          child: isReservationBusy &&
                                  !isReservationButtonDisabled
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(reservationButtonLabel),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _isDeleting ? null : _confirmDelete,
                          child: _isDeleting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('イベントを削除する'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadReservationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isReservationLoading = false);
      }
      return;
    }
    try {
      final hasReservation = await _eventService.hasReservation(
        eventId: _event.id,
        userId: user.uid,
      );
      if (!mounted) return;
      setState(() {
        _hasReservation = hasReservation;
        _isReservationLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isReservationLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('予約状況の取得に失敗しました')),
      );
    }
  }

  Future<void> _openEditEvent() async {
    final updatedEvent = await Navigator.of(context).push<CalendarEvent>(
      MaterialPageRoute(
        builder: (_) => EditEventPage(event: _event),
      ),
    );
    if (updatedEvent != null && mounted) {
      setState(() => _event = updatedEvent);
    }
  }

  Future<void> _onReservationButtonPressed() async {
    final isCancel = _hasReservation;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(isCancel ? '予約解除の確認' : '予約の確認'),
            content: Text(
              isCancel ? 'このイベントの予約を解除しますか？' : 'このイベントを予約しますか？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  isCancel ? '解除する' : '予約する',
                  style: TextStyle(
                    color: isCancel ? Colors.redAccent : null,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      await _toggleReservation();
    }
  }

  Future<void> _toggleReservation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('予約にはログインが必要です')),
      );
      return;
    }
    setState(() => _isReservationProcessing = true);
    try {
      if (_hasReservation) {
        await _eventService.cancelReservation(
          eventId: _event.id,
          userId: user.uid,
        );
        if (!mounted) return;
        setState(() => _hasReservation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('予約を解除しました')),
        );
      } else {
        await _eventService.reserveEvent(
          event: _event,
          userId: user.uid,
        );
        if (!mounted) return;
        setState(() => _hasReservation = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('予約しました')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final message = _hasReservation ? '予約の解除に失敗しました: $e' : '予約に失敗しました: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isReservationProcessing = false;
          _isReservationLoading = false;
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('削除の確認'),
            content: const Text('このイベントを削除しますか？この操作は元に戻せません。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  '削除する',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;

    setState(() => _isDeleting = true);
    try {
      await _eventService.deleteEvent(_event);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('イベントを削除しました')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除に失敗しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
