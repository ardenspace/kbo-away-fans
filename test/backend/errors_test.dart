/// Step 1.6 오류 봉투 단위 테스트 — Firebase 예외가 네트워크·권한·알 수 없음
/// 세 도메인 오류로만 나오는지, 그리고 변환 경로가 하나뿐인지 검증한다.
library;

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/errors.dart';

FirebaseException _firestoreError(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code, message: code);

FirebaseException _authError(String code) =>
    FirebaseException(plugin: 'firebase_auth', code: code, message: code);

void main() {
  group('BackendError.from — Firestore 예외', () {
    test('unavailable·deadline-exceeded 는 네트워크', () {
      for (final code in ['unavailable', 'deadline-exceeded']) {
        expect(
          BackendError.from(_firestoreError(code)),
          isA<BackendNetworkError>().having((e) => e.code, 'code', code),
          reason: code,
        );
      }
    });

    test('permission-denied·unauthenticated 는 권한', () {
      for (final code in ['permission-denied', 'unauthenticated']) {
        expect(
          BackendError.from(_firestoreError(code)),
          isA<BackendPermissionError>(),
          reason: code,
        );
      }
    });

    test('그 밖의 코드는 알 수 없음 — 코드는 보존한다', () {
      final error = BackendError.from(_firestoreError('aborted'));

      expect(error, isA<BackendUnknownError>());
      expect(error.code, 'aborted');
    });
  });

  group('BackendError.from — 인증 예외', () {
    test('network-request-failed 는 네트워크', () {
      expect(
        BackendError.from(_authError('network-request-failed')),
        isA<BackendNetworkError>(),
      );
    });

    test('세션이 죽은 코드는 권한', () {
      for (final code in ['user-disabled', 'user-token-expired']) {
        expect(
          BackendError.from(_authError(code)),
          isA<BackendPermissionError>(),
          reason: code,
        );
      }
    });
  });

  group('BackendError.from — Firebase 밖의 실패', () {
    test('TimeoutException 은 네트워크', () {
      expect(
        BackendError.from(TimeoutException('too slow')),
        isA<BackendNetworkError>(),
      );
    });

    test('그 밖의 예외는 알 수 없음이고 원인을 들고 있다', () {
      final cause = StateError('boom');

      final error = BackendError.from(cause);

      expect(error, isA<BackendUnknownError>());
      expect(error.cause, same(cause));
    });

    test('이미 도메인 오류면 그대로 돌려준다 (이중 포장 없음)', () {
      const original = BackendPermissionError(code: 'permission-denied');

      expect(BackendError.from(original), same(original));
    });
  });

  test('코드 로스터가 도메인을 하나씩만 가리킨다', () {
    for (final code in kNetworkErrorCodes) {
      expect(
        BackendError.from(_firestoreError(code)),
        isA<BackendNetworkError>(),
        reason: code,
      );
    }
    for (final code in kPermissionErrorCodes) {
      expect(
        BackendError.from(_firestoreError(code)),
        isA<BackendPermissionError>(),
        reason: code,
      );
    }
    expect(kNetworkErrorCodes.intersection(kPermissionErrorCodes), isEmpty);
  });

  group('guardBackend — 실패 경로의 단일 통로', () {
    test('성공하면 값을 그대로 돌려준다', () async {
      expect(await guardBackend(() async => 7), 7);
    });

    test('Firebase 예외를 도메인 오류로 바꿔 던진다', () {
      expect(
        () => guardBackend<void>(
          () async => throw _firestoreError('permission-denied'),
        ),
        throwsA(isA<BackendPermissionError>()),
      );
    });

    test('도메인 오류는 다시 포장하지 않는다', () {
      expect(
        () => guardBackend<void>(
          () async => throw const BackendNetworkError(code: 'unavailable'),
        ),
        throwsA(isA<BackendNetworkError>()),
      );
    });
  });

  group('guardBackendStream — 값이 계속 흐르는 경로 (step 2.1)', () {
    test('값 이벤트는 손대지 않고 그대로 흘린다', () {
      expect(guardBackendStream(Stream.fromIterable([1, 2, 3])), emitsInOrder([
        1,
        2,
        3,
        emitsDone,
      ]));
    });

    test('오류 이벤트만 도메인 오류로 바꾼다', () {
      final source = Stream<int>.multi((controller) {
        controller.add(1);
        controller.addError(_authError('network-request-failed'));
        controller.close();
      });
      expect(
        guardBackendStream(source),
        emitsInOrder([
          1,
          emitsError(
            isA<BackendNetworkError>().having(
              (e) => e.code,
              'code',
              'network-request-failed',
            ),
          ),
          emitsDone,
        ]),
      );
    });

    test('Firebase 밖의 실패도 도메인 오류로 나온다 (SDK 예외 유출 없음)', () {
      final source = Stream<int>.error(StateError('세션 스트림이 끊겼다'));
      expect(
        guardBackendStream(source),
        emitsInOrder([
          emitsError(isA<BackendUnknownError>()),
          emitsDone,
        ]),
      );
    });
  });
}
