/// 팀/구장 안정 id 로스터 — `content-pipeline/schema/common.defs.schema.json`
/// 의 enum 을 앱 쪽에 미러링한다.
///
/// 원본은 스키마 파일이다. 로스터가 바뀌면(= schemaVersion 마이그레이션급)
/// 여기와 `lib/design/team_themes.dart` 를 함께 갱신한다.
library;

/// 1군 10개 팀의 안정 id (common.defs `teamId` enum).
const Set<String> kTeamIds = {
  'lg',
  'doosan',
  'kiwoom',
  'ssg',
  'kt',
  'kia',
  'samsung',
  'lotte',
  'nc',
  'hanwha',
};

/// 1군 정규 홈구장 9곳의 안정 id (common.defs `stadiumId` enum).
/// 스탬프 인증 대비 불변 식별자로 취급한다.
const Set<String> kStadiumIds = {
  'jamsil',
  'gocheok',
  'munhak',
  'suwon',
  'daejeon',
  'daegu',
  'sajik',
  'changwon',
  'gwangju',
};

/// 계약상 팀 수 — teams.json 의 minItems/maxItems.
const int kTeamCount = 10;

/// 계약상 구장 수 — stadiums.json 의 minItems/maxItems.
const int kStadiumCount = 9;
