import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/ui/shared/stadium_picker.dart';

void main() {
  testWidgets('StadiumPicker가 렌더되고 선택 콜백이 불린다', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StadiumPicker(
            stadiums: const [
              StadiumPickerItem(id: 'sajik', label: '사직'),
              StadiumPickerItem(id: 'jamsil', label: '잠실'),
            ],
            onSelected: (id) => selected = id,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    await tester.tap(find.text('사직'));
    expect(selected, 'sajik');
  });
}
