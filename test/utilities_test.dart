import 'package:flutter_test/flutter_test.dart';
import 'package:stock_demo/Utils/utilities.dart';

void main() {
  test('Before market close -> returns previous day', () {
    final now = DateTime(2026, 4, 21, 15, 29); // 21 Apr 2026 15:29
    final last = Utilities.getLastWorkingDay(now);
    expect(last, DateTime(2026, 4, 20));
  });

  test('After market close -> returns today', () {
    final now = DateTime(2026, 4, 21, 15, 31); // 21 Apr 2026 15:31
    final last = Utilities.getLastWorkingDay(now);
    expect(last, DateTime(2026, 4, 21));
  });

  test('Weekend (Sunday) -> returns previous Friday', () {
    final now = DateTime(2026, 4, 19, 12, 0); // Sunday
    final last = Utilities.getLastWorkingDay(now);
    expect(last, DateTime(2026, 4, 17)); // Friday 17 Apr 2026
  });
}

