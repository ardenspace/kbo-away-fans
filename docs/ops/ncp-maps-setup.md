# ops — NCP Maps (Mobile Dynamic Map) Client ID 발급·설정 (R12)

> 코드 배선(`naver_map_config.dart` 의 `String.fromEnvironment('NCP_MAP_CLIENT_ID')`,
> main.dart degrade 경고)은 커밋됨. 아래는 **NCP 콘솔에서 사람이 하는 발급·등록·한도
> 설정** 수동 단계다.
>
> Client ID 실키는 저장소에 커밋하지 않는다. dart-define 은 저장소 위생 조치일 뿐
> 최종 바이너리에서 추출 가능하므로, **실질 통제는 콘솔의 번들 ID/패키지명 등록 +
> 한도 설정**이다.

## 1. Application 등록 & Client ID 발급 (console.ncloud.com)

1. NAVER Cloud Platform 콘솔 → **Services > AI·NAVER API > Maps** (또는
   Maps 상품) → **Application 등록**.
2. 사용 API 에서 **Mobile Dynamic Map** 체크 (앱 내 인터랙티브 지도 위젯).
3. 등록 완료 후 발급되는 **Client ID** = `--dart-define=NCP_MAP_CLIENT_ID` 로 주입할 값.
   - Client Secret 은 이 앱(모바일 Dynamic Map)에는 불필요. Client ID 만 사용.

## 2. 번들 ID / 패키지명 등록 (실질 통제선)

앱을 화이트리스트로 묶어 키 도용을 막는 단계 — dart-define 위생보다 이게 실질 방어다.

1. Application 설정 → **iOS Bundle ID** 등록: `com.ardenspace.kboAwayFans`
   (실제 값은 `app/ios/Runner.xcodeproj` 의 `PRODUCT_BUNDLE_IDENTIFIER` 로 확인).
2. Application 설정 → **Android 패키지명** 등록: `com.ardenspace.kbo_away_fans`
   (실제 값은 `app/android/app/build.gradle` 의 `applicationId` 로 확인).
3. 등록한 번들 ID / 패키지명과 앱 빌드의 값이 정확히 일치해야 지도 타일이 로드된다.

## 3. 무료 이용량 확인 & 한도 설정

계정 개설 시 콘솔에서 **직접 최신 수치를 확인**하고 상한을 건다 (요금 폭주 방지).

1. Maps 상품 요금/이용안내에서 **Mobile Dynamic Map 무료 이용량**(월 무료 제공
   호출/로드 수) 수치를 **콘솔에서 확인**해 기록한다. 문서 값이 아니라 콘솔의
   현재 값을 기준으로 삼는다.
2. **한도 설정**(사용량/요금 알림·상한)을 적용해 무료 이용량 근처에서 알림이 오고,
   초과 시 과금이 통제되도록 한다.
3. 적용 후 콘솔 대시보드에서 한도 설정이 실제로 걸렸는지 확인한다.

## 4. 주입 & 검증

값은 `.env` 로 런타임 로딩하는 게 아니다 — 코드가 `String.fromEnvironment`(컴파일
타임 상수)로 읽으므로 **빌드 시 `--dart-define` 으로 주입**해야 한다. 매번 3개를
치는 대신 JSON 파일 하나로 묶는다.

`app/dart_define.local.json` (실키; `.gitignore` 처리됨, 커밋 금지):

```json
{
  "SUPABASE_URL": "https://...supabase.co",
  "SUPABASE_ANON_KEY": "...",
  "NCP_MAP_CLIENT_ID": "<발급받은 Client ID>"
}
```

> 형식은 커밋된 `app/dart_define.example.json` 참고. 로컬 파일만 실값으로 채운다.

```bash
# app/ 에서
flutter run --dart-define-from-file=dart_define.local.json
```

`--dart-define` 을 개별로 넘기던 아래 방식과 동작은 완전히 동일하다(여전히 컴파일
타임 주입):

```bash
flutter run \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=NCP_MAP_CLIENT_ID=<발급받은 Client ID>
```

- **주입 시**: 지도 화면이 네이티브 지도 위젯을 렌더한다.
- **미주입 시**(`NCP_MAP_CLIENT_ID` 생략): `shouldDegradeMap` 이 true → 지도 화면은
  네이티브 위젯을 만들지 않고 안내 텍스트만 렌더한다. 스탬프 등 나머지 화면은
  정상 동작하며 **crash 하지 않는다** (R12). main.dart 는 debug 빌드에서 미주입
  경고를 콘솔에 남긴다.
