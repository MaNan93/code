import unittest

from plm.frontend.qt.styles import build_app_stylesheet


class QtFontFallbackTests(unittest.TestCase):
    def test_user_font_stays_first_and_cjk_fallbacks_follow(self):
        qss = build_app_stylesheet("DejaVu Sans", 13)
        expected = (
            'font-family: "DejaVu Sans", "Microsoft YaHei UI", "PingFang SC", '
            '"Noto Sans CJK SC", "SimHei", "SimSun", sans-serif;'
        )
        self.assertIn(expected, qss)

    def test_existing_cjk_font_is_not_duplicated(self):
        qss = build_app_stylesheet("Microsoft YaHei UI", 13)
        font_rule = next(
            line.strip() for line in qss.splitlines() if line.strip().startswith("font-family:")
        )
        self.assertEqual(font_rule.count('"Microsoft YaHei UI"'), 1)


if __name__ == "__main__":
    unittest.main()
