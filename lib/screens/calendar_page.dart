import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import '../services/event_service.dart';
import 'create_event_page.dart';
import 'event_detail_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static final DateTime _startDate = DateTime(2025, 12, 1);
  static final DateTime _endDate = DateTime(2030, 12, 31);

  final EventService _eventService = EventService();
  late final Stream<List<CalendarEvent>> _eventsStream =
      _eventService.watchEvents(_startDate, _endDate);

  late final int _monthCount = (_endDate.year - _startDate.year) * 12 +
      (_endDate.month - _startDate.month) +
      1;

  late final PageController _pageController;
  late int _currentPage;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _currentPage = _initialPageFor(DateTime.now());
    _pageController = PageController(initialPage: _currentPage);
    final today = DateTime.now();
    _selectedDate = today.isBefore(_startDate)
        ? _startDate
        : today.isAfter(_endDate)
            ? _endDate
            : today;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _initialPageFor(DateTime target) {
    if (target.isBefore(_startDate)) {
      return 0;
    }
    if (target.isAfter(_endDate)) {
      return _monthCount - 1;
    }
    return (target.year - _startDate.year) * 12 +
        (target.month - _startDate.month);
  }

  DateTime _monthForIndex(int index) {
    return DateTime(_startDate.year, _startDate.month + index, 1);
  }

  void _goToPage(int index) {
    if (index < 0 || index >= _monthCount) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _openCreateEvent() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateEventPage()),
    );
  }

  void _openEventDetail(CalendarEvent event) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EventDetailPage(event: event)),
    );
  }

  Widget _buildHeader(BuildContext context, DateTime currentMonth) {
    final theme = Theme.of(context);
    const textColor = Colors.black87;
    const subTextColor = Colors.black54;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  'イベントスケジュール',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: _openCreateEvent,
              icon: const Icon(Icons.add_circle_outline),
              color: theme.colorScheme.primary,
              tooltip: 'イベント作成',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              onPressed:
                  _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
              icon: const Icon(Icons.chevron_left, color: Colors.black45),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${currentMonth.year}年${currentMonth.month}月',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '対象期間：2025年12月1日〜2030年12月31日',
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: subTextColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _currentPage < _monthCount - 1
                  ? () => _goToPage(_currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right, color: Colors.black45),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentMonth = _monthForIndex(_currentPage);
    final background = Colors.white;
    final screenHeight = MediaQuery.of(context).size.height;
    final calendarHeight = math.max(screenHeight * 0.5, 450.0);

    return StreamBuilder<List<CalendarEvent>>(
      stream: _eventsStream,
      builder: (context, snapshot) {
        final eventsByDate = _groupEvents(snapshot.data ?? const <CalendarEvent>[]);
        final selectedEvents = _eventsForDate(eventsByDate, _selectedDate);

        return SafeArea(
          child: Container(
            color: background,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: _buildHeader(context, currentMonth),
                  ),
                  SizedBox(
                    height: calendarHeight,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _monthCount,
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                      },
                      itemBuilder: (context, index) {
                        final month = _monthForIndex(index);
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Column(
                            children: [
                              const _WeekdayHeader(),
                              const SizedBox(height: 16),
                              Expanded(
                                child: _MonthGrid(
                                  month: month,
                                  selectedDate: _selectedDate,
                                  eventsForMonth:
                                      _eventsForMonth(eventsByDate, month),
                                  onSelectDate: (date) {
                                    setState(() => _selectedDate = date);
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: _EventList(
                      selectedDate: _selectedDate,
                      events: selectedEvents,
                      weekdayLabel: _weekdayLabel,
                      isLoading:
                          snapshot.connectionState == ConnectionState.waiting,
                      onTap: _openEventDetail,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Map<String, List<CalendarEvent>> _groupEvents(
    List<CalendarEvent> events,
  ) {
    final Map<String, List<CalendarEvent>> result = {};
    for (final event in events) {
      final key = _dateKey(event.startDateTime);
      result.putIfAbsent(key, () => []).add(event);
    }
    return result;
  }

  List<CalendarEvent> _eventsForDate(
    Map<String, List<CalendarEvent>> grouped,
    DateTime? date,
  ) {
    if (date == null) return const [];
    return grouped[_dateKey(date)] ?? const [];
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Map<int, List<CalendarEvent>> _eventsForMonth(
    Map<String, List<CalendarEvent>> grouped,
    DateTime month,
  ) {
    final Map<int, List<CalendarEvent>> result = {};
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final events = grouped[_dateKey(date)];
      if (events != null && events.isNotEmpty) {
        result[day] = events;
      }
    }
    return result;
  }

  String _weekdayLabel(int weekday) {
    const labels = ['月', '火', '水', '木', '金', '土', '日'];
    return labels[(weekday + 6) % 7];
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  static const List<String> _labels = ['日', '月', '火', '水', '木', '金', '土'];

  @override
  Widget build(BuildContext context) {
    final color = Colors.black87;
    return Row(
      children: List.generate(_labels.length, (index) {
        final labelColor = index == 0
            ? Colors.red
            : index == 6
                ? Colors.blue
                : color;
        return Expanded(
          child: Text(
            _labels[index],
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: labelColor),
          ),
        );
      }),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selectedDate,
    required this.onSelectDate,
    required this.eventsForMonth,
  });

  final DateTime month;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelectDate;
  final Map<int, List<CalendarEvent>> eventsForMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final leadingEmpty = firstDayOfMonth.weekday % 7;
    final totalCells = ((leadingEmpty + daysInMonth + 6) ~/ 7) * 7;
    final Color weekdayColor = Colors.black87;
    final TextStyle baseStyle =
        theme.textTheme.bodySmall?.copyWith(fontSize: 11) ??
            const TextStyle(fontSize: 11);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 0.7,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        final dayNumber = index - leadingEmpty + 1;
        final isInMonth = dayNumber > 0 && dayNumber <= daysInMonth;
        final weekdayIndex = index % 7;
        final cellDate =
            isInMonth ? DateTime(month.year, month.month, dayNumber) : null;
        final isToday = cellDate == todayDate;
        final textColor = weekdayIndex == 0
            ? Colors.red
            : weekdayIndex == 6
                ? Colors.blue
                : weekdayColor;
        final isSelected =
            isInMonth && selectedDate != null && cellDate == selectedDate;
        final Color backgroundColor = !isInMonth
            ? Colors.transparent
            : isToday
                ? Colors.lightBlue.shade50
                : Colors.white;

        final events = isInMonth ? eventsForMonth[dayNumber] ?? const [] : const [];

        Widget cellContent = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: isSelected ? 2 : 0,
            ),
            color: backgroundColor,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  isInMonth ? '$dayNumber' : '',
                  style: baseStyle.copyWith(
                    color: isInMonth ? textColor : Colors.grey.shade300,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (events.isNotEmpty)
                  Column(
                    children: events
                        .take(2)
                        .map(
                          (event) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 2,
                                horizontal: 6,
                              ),
                              decoration: BoxDecoration(
                                color: event.color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                event.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                  color: event.color.withOpacity(0.9),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  )
                else
                  const SizedBox(height: 20),
              ],
            ),
          ),
        );

        if (!isInMonth || cellDate == null) {
          return cellContent;
        }

        return GestureDetector(
          onTap: () => onSelectDate(cellDate),
          child: cellContent,
        );
      },
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({
    required this.selectedDate,
    required this.events,
    required this.weekdayLabel,
    required this.isLoading,
    required this.onTap,
  });

  final DateTime? selectedDate;
  final List<CalendarEvent> events;
  final String Function(int weekday) weekdayLabel;
  final bool isLoading;
  final void Function(CalendarEvent event) onTap;

  @override
  Widget build(BuildContext context) {
    if (selectedDate == null) {
      return const SizedBox.shrink();
    }
    final label =
        '${selectedDate!.year}年${selectedDate!.month}月${selectedDate!.day}日（${weekdayLabel(selectedDate!.weekday)}）';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (isLoading && events.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          )
        else if (events.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('この日の予定はありません'),
          )
        else
          Column(
            children: events
                .map(
                  (event) => GestureDetector(
                    onTap: () => onTap(event),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 18,
                      ),
                      decoration: BoxDecoration(
                        color: event.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: event.color.withOpacity(0.4),
                        ),
                      ),
                      child: _EventTile(event: event),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final CalendarEvent event;

  String get _timeLabel {
    String format(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${format(event.startDateTime)}〜${format(event.endDateTime)}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.event, color: event.color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.name,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '主催: ${event.organizer.isNotEmpty ? event.organizer : '未設定'} / 時間: $_timeLabel',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: event.color),
              ),
              if (event.content.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  event.content,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

Widget _schedulePlaceholder(bool isActive, ThemeData theme, {double height = 6}) {
  return Container(
    height: height,
    width: double.infinity,
    decoration: BoxDecoration(
      color: isActive ? Colors.black12 : Colors.transparent,
      borderRadius: BorderRadius.circular(3),
    ),
  );
}
