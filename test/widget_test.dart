import 'package:flutter_test/flutter_test.dart';

import 'package:doc_scanner/main.dart';

void main() {
  testWidgets('App 启动显示扫描入口', (WidgetTester tester) async {
    await tester.pumpWidget(const ScanApp());
    await tester.pump();

    // 空状态首页应有「开始扫描」按钮
    expect(find.text('开始扫描'), findsOneWidget);
  });
}
