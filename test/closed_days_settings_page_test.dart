import 'package:cocoshiba_app/screens/closed_days_settings_page.dart';
import 'package:cocoshiba_app/services/closed_days_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ClosedDaysServiceStub implements ClosedDaysService {
  _ClosedDaysServiceStub(this.savedDays);

  final Map<DateTime, ClosedDayType> savedDays;
  Map<DateTime, ClosedDayType?>? lastChanges;

  @override
  Future<Map<DateTime, ClosedDayType>> fetchClosedDays({
    required DateTime startDate,
    required DateTime endDate,
  }) async =>
      Map.of(savedDays);

  @override
  Future<void> saveClosedDayChanges(
      Map<DateTime, ClosedDayType?> changes) async {
    lastChanges = Map.of(changes);
    for (final entry in changes.entries) {
      final type = entry.value;
      if (type == null) {
        savedDays.remove(entry.key);
      } else {
        savedDays[entry.key] = type;
      }
    }
  }
}

void main() {
  testWidgets('休業区分を変更・解除し、保存して開き直せる', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 667);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final now = DateTime.now();
    final start = DateTime(2025, 12);
    final end = DateTime(2030, 12);
    final currentMonth = DateTime(now.year, now.month);
    final month = currentMonth.isBefore(start)
        ? start
        : currentMonth.isAfter(end)
            ? end
            : currentMonth;
    DateTime date(int day) => DateTime(month.year, month.month, day);

    final service = _ClosedDaysServiceStub({
      date(1): ClosedDayType.regular,
      date(2): ClosedDayType.regular,
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ClosedDaysSettingsPage(service: service),
            )),
            child: const Text('設定を開く'),
          ),
        ),
      ),
    ));

    final grid = find.byType(GridView);
    Finder inGrid(String text) =>
        find.descendant(of: grid, matching: find.text(text));
    Future<void> tap(Finder finder) async {
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await tap(find.text('設定を開く'));
    expect(inGrid('定休日'), findsNWidgets(2));
    await tap(inGrid('2'));
    await tap(find.text('臨時休業'));
    await tap(inGrid('1'));
    await tap(inGrid('3'));
    await tap(find.text('定休日'));
    await tap(inGrid('4'));
    expect(inGrid('臨時休業'), findsNWidgets(2));
    expect(inGrid('定休日'), findsOneWidget);

    await tap(find.text('保存'));
    await tap(find.text('保存する'));
    expect(service.lastChanges, {
      date(1): ClosedDayType.temporary,
      date(2): null,
      date(3): ClosedDayType.temporary,
      date(4): ClosedDayType.regular,
    });

    await tap(find.text('設定を開く'));
    expect(inGrid('臨時休業'), findsNWidgets(2));
    expect(inGrid('定休日'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
