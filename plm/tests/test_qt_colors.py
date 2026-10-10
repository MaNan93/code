"""Keep small muted labels readable on the surfaces that use them."""

import unittest

from plm.frontend.qt.styles.tokens import (
    BG_ARTIFACTS, BG_SIDEBAR, BG_SUBTLE, BG_SURFACE, TEXT_MUTED,
)


def luminance(color):
    channels = [int(color[index:index + 2], 16) / 255 for index in (1, 3, 5)]
    linear = [value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4
              for value in channels]
    return sum(value * weight for value, weight in zip(linear, (0.2126, 0.7152, 0.0722)))


class MutedTextContrastTests(unittest.TestCase):
    def test_muted_labels_meet_required_contrast_on_resting_surfaces(self):
        for surface in (BG_SIDEBAR, BG_ARTIFACTS, BG_SUBTLE, BG_SURFACE):
            with self.subTest(surface=surface):
                light, dark = sorted((luminance(surface), luminance(TEXT_MUTED)), reverse=True)
                self.assertGreaterEqual((light + 0.05) / (dark + 0.05), 4.5)
