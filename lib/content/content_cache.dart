/// 콘텐츠 JSON 로컬 캐시 — 문서 종류별 파일 하나씩.
library;

import 'dart:io';

import 'content_loader.dart';

/// 검증을 통과한 콘텐츠 문서의 원문(raw JSON)을 파일로 보관한다.
///
/// - 저장 방식: 문서 종류별로 `<directory>/<kind>.json` 파일 하나
///   (hive/shared_preferences 대신 파일 — 문서가 통째로 갱신되는
///   원격 JSON 번들과 1:1 이고 플러그인 없이 단위 테스트 가능).
/// - 만료 정책: 없음. 로더가 항상 네트워크 우선이라 캐시는
///   "마지막으로 검증을 통과한 문서"의 최후 폴백으로만 쓰인다.
/// - 쓰기는 임시 파일 + rename 으로 원자적 교체(중단 시 반쪽 파일 방지).
class ContentCache {
  ContentCache(this.directory);

  /// 캐시 파일이 놓일 디렉터리 (없으면 첫 쓰기 때 생성).
  final Directory directory;

  File _file(ContentKind kind) =>
      File('${directory.path}${Platform.pathSeparator}${kind.fileName}');

  /// 캐시된 원문. 없거나 읽기 실패면 null.
  Future<String?> read(ContentKind kind) async {
    final file = _file(kind);
    try {
      if (!await file.exists()) return null;
      return await file.readAsString();
    } on FileSystemException {
      return null;
    }
  }

  /// 검증 통과한 원문을 원자적으로 기록한다.
  Future<void> write(ContentKind kind, String body) async {
    await directory.create(recursive: true);
    final target = _file(kind);
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(body, flush: true);
    await tmp.rename(target.path);
  }
}
