"""Task 1.1 (R15): stadiums.json 잠실 LG 행 파일 단언.

크롤러 별칭표("잠실"→"잠실야구장")와 비충돌하도록 LG 행 name 이 기존
"잠실야구장"과 문자열 불일치임을 기계 검증한다.

실행: python3 -m unittest scripts/test_stadiums_seed.py
(시드 재적재 `python3 scripts/seed.py` 는 원격 DB 대상 수동 ops 단계.)
"""
import json
import unittest
from pathlib import Path

DATA = Path(__file__).parent / "seed" / "data" / "stadiums.json"
JAMSIL_NAME = "잠실야구장"


class StadiumsSeedTest(unittest.TestCase):
    def setUp(self):
        self.stadiums = json.loads(DATA.read_text())

    def test_ten_entries(self):
        self.assertEqual(len(self.stadiums), 10)

    def test_two_jamsil_coord_entries(self):
        base = next(s for s in self.stadiums if s["name"] == JAMSIL_NAME)
        coord = (base["lat"], base["lng"])
        shared = [s for s in self.stadiums if (s["lat"], s["lng"]) == coord]
        self.assertEqual(len(shared), 2)
        names = {s["name"] for s in shared}
        self.assertEqual(len(names), 2, "두 잠실 항목 name 은 고유해야 한다")
        self.assertIn(JAMSIL_NAME, names)

    def test_lg_row(self):
        base = next(s for s in self.stadiums if s["name"] == JAMSIL_NAME)
        lg = next(s for s in self.stadiums if s.get("team_abbr") == "LG")
        self.assertNotEqual(lg["name"], JAMSIL_NAME)
        self.assertEqual((lg["lat"], lg["lng"]), (base["lat"], base["lng"]))
        self.assertEqual(set(lg.keys()), set(base.keys()), "동일 스키마 필드")


if __name__ == "__main__":
    unittest.main()
