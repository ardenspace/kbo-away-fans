import 'package:flutter/material.dart';

/// 앱 루트 위젯.
///
/// 디자인 토큰(`lib/design/`)이 만들어지면 여기서 ThemeData로 연결한다.
/// 그전까지는 임시 자리 화면만 둔다.
class KboAwayFansApp extends StatelessWidget {
  const KboAwayFansApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'KBO 원정 도장깨기',
      home: Scaffold(
        body: Center(
          child: Text('KBO 원정 도장깨기'),
        ),
      ),
    );
  }
}
