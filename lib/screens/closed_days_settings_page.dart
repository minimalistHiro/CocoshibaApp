import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/closed_days_service.dart';

class ClosedDaysSettingsPage extends StatefulWidget {
  const ClosedDaysSettingsPage({super.key});

  @override
  State<ClosedDaysSettingsPage> createState() => _ClosedDaysSettingsPageState();
}

class _ClosedDaysSettingsPageState extends State<ClosedDaysSettingsPage> {
  static final DateTime _startDate = DateTime(2025, 12, 1);
  static final DateTime _endDate = DateTime(2030, 12, 31);

  final ClosedDaysService _service = ClosedDaysService();
  final Set<DateTime> _persistedClosedDays = <DateTime>{};
  final Set<DateTime> _selectedDates = <DateTime>{};

  late final int _monthCount = (_endDate.year - _startDate.year) * 12 +
      (_endDate.month - _startDate.month) +
      1;
  late final PageController _pageController;
  late int _currentPage;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentPage = _initialPageFor(DateTime.now());
    _pageController = PageController(initialPage: _currentPage);
    _loadClosedDays();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _initialPageFor(DateTime target) {
    if (target.isBefore(_startDate)) return 0;
    if (target.isAfter(_endDate)) return _monthCount - 1;
    return (target.year - _startDate.year) * 12 +
        (target.month - _startDate.month);
  }

  DateTime _monthForIndex(int index) {
    return DateTime(_startDate.year, _startDate.month + index, 1);
  }

  DateTime _normalize(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Future<void> _loadClosedDays() async {
    try {
      final closedDays = await _service.fetchClosedDays(
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted) return;
      setState(() {
        _persistedClosedDays
          ..clear()
          ..addAll(closedDays.map(_normalize));
        _selectedDates
          ..clear()
          ..addAll(_persistedClosedDays);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('定休日の取得に失敗しました')),
      );
    }
  }

  void _toggleDate(DateTime date) {
    if (_isSaving) return;
    final normalized = _normalize(date);
    setState(() {
      if (_selectedDates.contains(normalized)) {
        _selectedDates.remove(normalized);
      } else {
        _selectedDates.add(normalized);
      }
    });
  }

  Future<void> _confirmAndSave() async {
    if (_isSaving) return;
    final shouldSave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('確認'),
            content: Text('選択中の${_selectedDates.length}日を定休日として保存しますか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('保存する'),
              ),
            ],
          ),
        ) ??
        false;
    if (!mounted || !shouldSave) return;
    await _save();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.saveClosedDays(_selectedDates);
      if (!mounted) return;
      _persistedClosedDays
        ..clear()
        ..addAll(_selectedDates);
      messenger.showSnackBar(
        SnackBar(content: Text('定休日を${_selectedDates.length}件保存しました')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('定休日の保存に失敗しました')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentMonth = _monthForIndex(_currentPage);
    final screenHeight = MediaQuery.of(context).size.height;
    final calendarHeight = math.max(screenHeight * 0.55, 500.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('定休日設定'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '休業日にしたい日をカレンダーから複数選択して保存してください。',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _currentPage > 0
                                  ? () => _pageController.previousPage(
                                        duration:
                                            const Duration(milliseconds: 250),
                                        curve: Curves.easeInOut,
                                      )
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '${currentMonth.year}年${currentMonth.month}月',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    '対象期間：2025年12月1日〜2030年12月31日',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _currentPage < _monthCount - 1
                                  ? () => _pageController.nextPage(
                                        duration:
                                            const Duration(milliseconds: 250),
                                        curve: Curves.easeInOut,
                                      )
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ],
                    ),
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
                              const SizedBox(height: 12),
                              Expanded(
                                child: _ClosedDaysMonthGrid(
                                  month: month,
                                  persistedClosedDays: _persistedClosedDays,
                                  selectedDates: _selectedDates,
                                  onToggleDate: _toggleDate,
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
                      vertical: 8,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '選択中：${_selectedDates.length}日',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _confirmAndSave,
                      icon: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_isSaving ? '保存中...' : '保存'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  static const List<String> _labels = ['日', '月', '火', '水', '木', '金', '土'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_labels.length, (index) {
        final labelColor = index == 0
            ? Colors.red
            : index == 6
                ? Colors.blue
                : Colors.black87;
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

class _ClosedDaysMonthGrid extends StatelessWidget {
  const _ClosedDaysMonthGrid({
    required this.month,
    required this.persistedClosedDays,
    required this.selectedDates,
    required this.onToggleDate,
  });

  final DateTime month;
  final Set<DateTime> persistedClosedDays;
  final Set<DateTime> selectedDates;
  final ValueChanged<DateTime> onToggleDate;

  bool _isSelected(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return selectedDates.contains(normalized);
  }

  bool _isPersisted(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return persistedClosedDays.contains(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final leadingEmpty = firstDayOfMonth.weekday % 7;
    final totalCells = ((leadingEmpty + daysInMonth + 6) ~/ 7) * 7;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 0.8,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        final dayNumber = index - leadingEmpty + 1;
        final isInMonth = dayNumber > 0 && dayNumber <= daysInMonth;
        final weekdayIndex = index % 7;
        final DateTime? cellDate =
            isInMonth ? DateTime(month.year, month.month, dayNumber) : null;
        final bool isToday = cellDate != null && cellDate == todayDate;
        final bool isSelected =
            cellDate != null && isInMonth && _isSelected(cellDate);
        final bool isPersisted =
            cellDate != null && isInMonth && _isPersisted(cellDate);
        final textColor = weekdayIndex == 0
            ? Colors.red
            : weekdayIndex == 6
                ? Colors.blue
                : Colors.black87;

        final Widget cell = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.blueGrey : Colors.transparent,
              width: isSelected ? 2 : 0,
            ),
            color: !isInMonth
                ? Colors.transparent
                : isPersisted
                    ? Colors.grey.shade300
                    : isSelected
                        ? Colors.blue.shade50
                    : isToday
                        ? Colors.blue.shade50
                        : Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  isInMonth ? '$dayNumber' : '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isInMonth ? textColor : Colors.grey.shade400,
                      ) ??
                      TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isInMonth ? textColor : Colors.grey.shade400,
                      ),
                ),
                const SizedBox(height: 8),
                if (isPersisted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade500.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '定休日',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (isSelected)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '選択中',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  const Spacer(),
              ],
            ),
          ),
        );

        if (!isInMonth || cellDate == null) {
          return cell;
        }

        return GestureDetector(
          onTap: () => onToggleDate(cellDate),
          child: cell,
        );
      },
    );
  }
}
