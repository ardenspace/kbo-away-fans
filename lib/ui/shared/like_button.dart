import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// 좋아요 토글 — 누르는 즉시 반영하고, 쓰기가 실패하면 되돌린다.
///
/// 서버 응답을 기다렸다 모습을 바꾸면 네트워크가 느린 자리에서 "눌렸나?"가
/// 되어 두 번 누르게 된다. 그래서 [liked] 를 그대로 그리지 않고 눌린 결과를
/// 먼저 화면에 올린 뒤 [onChanged] 를 부르고, 그것이 실패하면 눌리기 전
/// 모습으로 되돌린 다음 [onFailed] 로 알린다.
///
/// 실패를 삼키지 않는 것이 중요하다 — 되돌리기만 하면 화면이 조용히 원래대로
/// 돌아가서 사용자는 자기가 잘못 눌렀다고 읽는다. 안내를 띄우는 일은 화면의
/// 몫이라 이 위젯은 알리기만 한다.
///
/// 응답을 기다리는 동안의 탭은 무시한다. 연타를 그대로 흘려보내면 마지막
/// 상태와 서버의 상태가 어긋날 수 있다.
class LikeButton extends StatefulWidget {
  const LikeButton({
    super.key,
    required this.liked,
    required this.onChanged,
    this.onFailed,
    this.semanticLabel = '좋아요',
  });

  /// 켜진 좋아요의 아이콘.
  static const IconData likedIcon = Icons.favorite_rounded;

  /// 꺼진 좋아요의 아이콘.
  static const IconData unlikedIcon = Icons.favorite_border_rounded;

  /// 지금까지 알려진 상태 (서버에서 읽은 값).
  final bool liked;

  /// 바뀐 상태를 서버에 쓴다. 던지면 실패로 본다.
  final Future<void> Function(bool liked) onChanged;

  /// 쓰기 실패를 화면에 알리는 경로 (되돌린 뒤에 불린다).
  final void Function(Object error)? onFailed;

  /// 스크린리더가 읽을 이름.
  final String semanticLabel;

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  late bool _liked = widget.liked;
  bool _pending = false;

  @override
  void didUpdateWidget(LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 바깥에서 값이 바뀌면 (다른 화면에서 눌렀거나 다시 읽었거나) 따라간다.
    if (widget.liked != oldWidget.liked) _liked = widget.liked;
  }

  Future<void> _toggle() async {
    if (_pending) return;
    final next = !_liked;
    setState(() {
      _liked = next;
      _pending = true;
    });

    try {
      await widget.onChanged(next);
    } catch (error) {
      if (mounted) setState(() => _liked = !next);
      widget.onFailed?.call(error);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _toggle,
      tooltip: widget.semanticLabel,
      icon: Icon(
        _liked ? LikeButton.likedIcon : LikeButton.unlikedIcon,
        color: _liked ? ColorTokens.danger : ColorTokens.textSecondary,
      ),
    );
  }
}
