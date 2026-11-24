import 'package:flutter/material.dart';

import '../services/closed_days_service.dart';

class ClosedDaysSettingsPage extends StatefulWidget {
  const ClosedDaysSettingsPage({super.key, this.service});

  final ClosedDaysService? service;

  @override
  State<ClosedDaysSettingsPage> createState() => _ClosedDaysSettingsPageState();
}

class _ClosedDaysSettingsPageState extends State<ClosedDaysSettingsPage> {
  static final DateTime _startDate = DateTime(2025, 12, 1);
  static final DateTime _endDate = DateTime(2030, 12, 31);

  late final _service = widget.service ?? ClosedDaysService();
  Map<DateTime, ClosedDayType> _persistedClosedDays = {};
  final _selectedDates = <DateTime, ClosedDayType>{};
  ClosedDayType _selectedType = ClosedDayType.regular;

  late final int _monthCount = (_endDate.year - _startDate.year) * 12 +
      (_endDate.month - _startDate.month) +
      1;
  late final PageController _pageController;
  late int _currentPage;

  bool _isLoading = true;
  bool _loadFailed = false;
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

  Future<void> _loadClosedDays() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final closedDays = await _service.fetchClosedDays(
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted) return;
      setState(() {
        _persistedClosedDays = closedDays;
        _selectedDates
          ..clear()
          ..addAll(_persistedClosedDays);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  void _toggleDate(DateTime date) {
    if (_isSaving) return;
    setState(() {
      if (_selectedDates[date] == _selectedType) {
        _selectedDates.remove(date);
      } else {
        _selectedDates[date] = _selectedType;
      }
    });
  }

  Future<void> _confirmAndSave() async {
    if (_isSaving) return;
    final changes = <DateTime, ClosedDayType?>{
      for (final date in _persistedClosedDays.keys)
        if (!_selectedDates.containsKey(date)) date: null,
      for (final entry in _selectedDates.entries)
        if (_persistedClosedDays[entry.key] != entry.value)
          entry.key: entry.value,
    };
    final temporaryCount = _selectedDates.values
        .where((type) => type == ClosedDayType.temporary)
        .length;
    final regularCount = _selectedDates.length - temporaryCount;
    final shouldSave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('確認'),
            content: Text(
              '休業日の設定を保存しますか？\n定休日 $regularCount日、臨時休業 $temporaryCount日',
            ),
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
    await _save(changes);
  }

  Future<void> _save(Map<DateTime, ClosedDayType?> changes) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.saveClosedDayChanges(changes);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('休業日の設定を保存しました')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('休業日の保存に失敗しました')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentMonth = _monthForIndex(_currentPage);

    return Scaffold(
      appBar: AppBar(
        title: const Text('定休日設定'),
      ),
      body: SafeArea(
        child: _isLoading || _loadFailed
            ? _buildLoadStatus()
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '休業の種類を選び、カレンダーで日付を選択してください。',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<ClosedDayType>(
                            segments: [
                              for (final type in ClosedDayType.values)
                                ButtonSegment(
                                  value: type,
                                  label: Text(type.label),
                                ),
                            ],
                            selected: {_selectedType},
                            onSelectionChanged: _isSaving
                                ? null
                                : (selection) => setState(
                                      () => _selectedType = selection.single,
                                    ),
                          ),
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
                  Expanded(
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

  Widget _buildLoadStatus() {
    return Center(
      child: _isLoading
          ? const CircularProgressIndicator()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('休業日の取得に失敗しました'),
                TextButton(
                  onPressed: _loadClosedDays,
                  child: const Text('再読み込み'),
                ),
              ],
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
    required this.selectedDates,
    required this.onToggleDate,
  });

  final DateTime month;
  final Map<DateTime, ClosedDayType> selectedDates;
  final ValueChanged<DateTime> onToggleDate;

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
      padding: EdgeInsets.zero,
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
        final type = selectedDates[cellDate];
        final isSelected = type != null;
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
                : isSelected
                    ? Colors.grey.shade300
                    : isToday
                        ? Colors.blue.shade50
                        : Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
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
                if (type != null) ...[
                  const SizedBox(height: 4),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 2,
                        horizontal: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          type.label,
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
