import unittest
import sys
import os
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from modules.redaction_engine import (
    redact_text,
    redact_image,
    _find_word_boxes_for_pii,
    _get_replacement_text
)


class TestRedactionEngine(unittest.TestCase):
    """Unit tests for exact text and visual image redactions."""

    def test_text_redaction_duplicate_words(self):
        """Test that duplicate words are only redacted at the specified offset."""
        text = "Employee John Doe reports to Manager John Doe in Department A."
        # Redact only the first 'John Doe' (offset 9 to 17)
        dets = [
            {'type': 'PERSON_NAME', 'value': 'John Doe', 'start': 9, 'end': 17, 'decision': 'FULL_REDACT'}
        ]
        redacted = redact_text(text, dets)
        self.assertIn("Manager John Doe", redacted)
        self.assertNotIn("Employee John Doe", redacted)
        self.assertIn("████████", redacted)

    def test_mask_formats(self):
        """Test formatting of partial masking decisions."""
        phone_det = {'type': 'PHONE', 'value': '9876543210', 'decision': 'PARTIAL_MASK'}
        self.assertEqual(_get_replacement_text('9876543210', phone_det), 'XXXXXX3210')

        email_det = {'type': 'EMAIL', 'value': 'john.smith@gmail.com', 'decision': 'PARTIAL_MASK'}
        masked_email = _get_replacement_text('john.smith@gmail.com', email_det)
        self.assertIn('@gmail.com', masked_email)
        self.assertTrue(masked_email.startswith('j***@'))

        name_det = {'type': 'PERSON_NAME', 'value': 'Rajesh Kumar', 'decision': 'PARTIAL_MASK'}
        self.assertEqual(_get_replacement_text('Rajesh Kumar', name_det), 'R***** K****')

    def test_bounding_box_sequence_matching_no_over_redaction(self):
        """Verify that sub-words like 'a' or 'in' do NOT get mistakenly redacted."""
        ocr_words = [
            {'text': 'Government', 'x': 10, 'y': 10, 'w': 80, 'h': 20},
            {'text': 'of', 'x': 95, 'y': 10, 'w': 20, 'h': 20},
            {'text': 'India', 'x': 120, 'y': 10, 'w': 40, 'h': 20},
            {'text': 'Name:', 'x': 10, 'y': 40, 'w': 40, 'h': 20},
            {'text': 'Rajesh', 'x': 55, 'y': 40, 'w': 50, 'h': 20},
            {'text': 'Kumar', 'x': 110, 'y': 40, 'w': 45, 'h': 20},
        ]
        # PII to redact is 'Rajesh Kumar'
        boxes = _find_word_boxes_for_pii('Rajesh Kumar', ocr_words)
        self.assertEqual(len(boxes), 1)
        # Bounding box should span x:55 to x:155, y:40 to y:60
        self.assertEqual(boxes[0]['x'], 55)
        self.assertEqual(boxes[0]['y'], 40)
        self.assertEqual(boxes[0]['w'], 100)
        self.assertEqual(boxes[0]['h'], 20)

        # Ensure 'of' or 'in' or 'Government' is NOT in boxes
        of_box = _find_word_boxes_for_pii('Rajesh Kumar', [ocr_words[1]])
        self.assertEqual(len(of_box), 0)

    def test_redact_image_visual(self):
        """Test image redaction drawing solid boxes and mosaic."""
        # Create blank white image (100x200)
        img = np.ones((100, 200, 3), dtype=np.uint8) * 255
        ocr_words = [
            {'text': '9876543210', 'x': 20, 'y': 20, 'w': 80, 'h': 20}
        ]
        dets = [
            {'type': 'PHONE', 'value': '9876543210', 'decision': 'FULL_REDACT'}
        ]
        redacted = redact_image(img, dets, ocr_words)
        self.assertIsNotNone(redacted)
        # Center of the redacted box should be black (0, 0, 0)
        center_pixel = redacted[30, 60]
        self.assertEqual(list(center_pixel), [0, 0, 0])

    def test_none_image_handling(self):
        """Ensure redaction engine gracefully accepts None for text-only files."""
        res = redact_image(None, [{'type': 'PAN', 'value': 'ABCPK1234F'}], [])
        self.assertIsNone(res)


if __name__ == '__main__':
    unittest.main()

