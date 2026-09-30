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

    def test_redact_vs_mask_vs_blur_materially_different_outputs(self):
        """Verify that REDACT, MASK, and BLUR produce materially different visual and textual outputs."""
        # Create synthetic test image with patterned content (120x240)
        img = np.zeros((120, 240, 3), dtype=np.uint8)
        # Add high-contrast gradient/pattern
        for r in range(120):
            img[r, :, :] = (r * 2) % 255
        # Add synthetic sensitive text block at (30, 30, w:100, h:30)
        img[30:60, 30:130] = [255, 255, 255]

        ocr_words = [{'text': '9876543210', 'x': 30, 'y': 30, 'w': 100, 'h': 30}]

        # 1. FULL_REDACT
        det_redact = [{'type': 'PHONE', 'value': '9876543210', 'decision': 'FULL_REDACT'}]
        out_redact = redact_image(img, det_redact, ocr_words)

        # 2. PARTIAL_MASK
        det_mask = [{'type': 'PHONE', 'value': '9876543210', 'decision': 'PARTIAL_MASK'}]
        out_mask = redact_image(img, det_mask, ocr_words)

        # 3. BLUR
        det_blur = [{'type': 'PHONE', 'value': '9876543210', 'decision': 'BLUR'}]
        out_blur = redact_image(img, det_blur, ocr_words)

        # Redact must be solid black in center
        self.assertEqual(list(out_redact[45, 80]), [0, 0, 0])

        # Mask must NOT be solid black
        self.assertNotEqual(list(out_mask[45, 80]), [0, 0, 0])

        # All three visual outputs must be mutually distinct
        self.assertFalse(np.array_equal(out_redact, out_mask), "Redact and Mask must differ visually")
        self.assertFalse(np.array_equal(out_redact, out_blur), "Redact and Blur must differ visually")
        self.assertFalse(np.array_equal(out_mask, out_blur), "Mask and Blur must differ visually")

        # Surrounding image outside bounding box must remain identical across all modes
        self.assertTrue(np.array_equal(out_redact[100:115, 150:220], img[100:115, 150:220]))
        self.assertTrue(np.array_equal(out_mask[100:115, 150:220], img[100:115, 150:220]))
        self.assertTrue(np.array_equal(out_blur[100:115, 150:220], img[100:115, 150:220]))

        # Text outputs must also be materially different
        sample_text = "Phone number is 9876543210."
        text_redact = redact_text(sample_text, det_redact)
        text_mask = redact_text(sample_text, det_mask)
        text_blur = redact_text(sample_text, det_blur)

        self.assertIn("██████████", text_redact)
        self.assertIn("XXXXXX3210", text_mask)
        self.assertIn("[BLURRED]", text_blur)
        self.assertNotEqual(text_redact, text_mask)
        self.assertNotEqual(text_redact, text_blur)
        self.assertNotEqual(text_mask, text_blur)

    def test_multi_word_sequence_matching_strategy_3(self):
        """Test that multi-word OCR tokens matching continuous PII value are correctly unified."""
        ocr_words = [
            {'text': 'UIDAI', 'x': 10, 'y': 10, 'w': 40, 'h': 15},
            {'text': '5432', 'x': 60, 'y': 10, 'w': 35, 'h': 15},
            {'text': '6789', 'x': 100, 'y': 10, 'w': 35, 'h': 15},
            {'text': '0123', 'x': 140, 'y': 10, 'w': 35, 'h': 15},
        ]
        # PII detected as continuous 12-digit number
        boxes = _find_word_boxes_for_pii('543267890123', ocr_words)
        self.assertEqual(len(boxes), 1)
        self.assertEqual(boxes[0]['x'], 60)
        self.assertEqual(boxes[0]['y'], 10)
        self.assertEqual(boxes[0]['w'], 115)  # Spanning from x:60 to x:175
        self.assertEqual(boxes[0]['h'], 15)

    def test_none_image_handling(self):
        """Ensure redaction engine gracefully accepts None for text-only files."""
        res = redact_image(None, [{'type': 'PAN', 'value': 'ABCPK1234F'}], [])
        self.assertIsNone(res)

    def test_manual_single_region_redact(self):
        """Test manual single region with action=redact."""
        img = np.ones((100, 200, 3), dtype=np.uint8) * 255
        # Manual region normalized: x=0.2, y=0.2, w=0.4, h=0.3
        manual_regions = [{'x': 0.2, 'y': 0.2, 'width': 0.4, 'height': 0.3, 'action': 'redact'}]
        redacted = redact_image(img, detections=[], ocr_words=[], manual_regions=manual_regions)
        self.assertIsNotNone(redacted)
        # Center of manual box: x=0.2*200+40=80, y=0.2*100+15=35 -> should be black (0, 0, 0)
        self.assertEqual(list(redacted[35, 80]), [0, 0, 0])
        # Area outside manual box must remain white (255, 255, 255)
        self.assertEqual(list(redacted[5, 5]), [255, 255, 255])

    def test_manual_single_region_mask(self):
        """Test manual single region with action=mask."""
        img = np.ones((100, 200, 3), dtype=np.uint8) * 255
        manual_regions = [{'x': 0.2, 'y': 0.2, 'width': 0.4, 'height': 0.3, 'action': 'mask'}]
        masked = redact_image(img, detections=[], ocr_words=[], manual_regions=manual_regions)
        self.assertIsNotNone(masked)
        # Bounding box should not be solid black or pure white
        self.assertNotEqual(list(masked[35, 80]), [0, 0, 0])
        # Outside remains intact
        self.assertEqual(list(masked[5, 5]), [255, 255, 255])

    def test_manual_single_region_blur(self):
        """Test manual single region with action=blur."""
        # Create patterned image with sharp high-contrast alternating stripes
        img = np.zeros((100, 200, 3), dtype=np.uint8)
        img[20:50:2, 40:120] = [255, 255, 255]
        img[21:50:2, 40:120] = [0, 0, 0]

        manual_regions = [{'x': 0.2, 'y': 0.2, 'width': 0.4, 'height': 0.3, 'action': 'blur'}]
        blurred = redact_image(img, detections=[], ocr_words=[], manual_regions=manual_regions)
        self.assertIsNotNone(blurred)
        # Must differ from original pattern inside box
        self.assertFalse(np.array_equal(blurred[20:50, 40:120], img[20:50, 40:120]))
        # Outside box remains identical
        self.assertTrue(np.array_equal(blurred[70:90, 150:190], img[70:90, 150:190]))

    def test_multiple_manual_regions(self):
        """Test applying multiple non-overlapping manual regions simultaneously."""
        img = np.ones((200, 300, 3), dtype=np.uint8) * 255
        manual_regions = [
            {'x': 0.1, 'y': 0.1, 'width': 0.2, 'height': 0.2, 'action': 'redact'},
            {'x': 0.6, 'y': 0.6, 'width': 0.2, 'height': 0.2, 'action': 'redact'},
        ]
        redacted = redact_image(img, detections=[], ocr_words=[], manual_regions=manual_regions)
        # Region 1 center: x=45, y=30
        self.assertEqual(list(redacted[30, 45]), [0, 0, 0])
        # Region 2 center: x=210, y=140
        self.assertEqual(list(redacted[140, 210]), [0, 0, 0])
        # Center of image between regions remains untouched white
        self.assertEqual(list(redacted[100, 150]), [255, 255, 255])

    def test_manual_out_of_bounds_clamping(self):
        """Ensure invalid or negative coordinates are clamped safely without throwing exceptions."""
        img = np.ones((100, 200, 3), dtype=np.uint8) * 255
        bad_regions = [
            {'x': -0.5, 'y': -0.2, 'width': 2.0, 'height': 3.0, 'action': 'redact'},
            {'x': 0.9, 'y': 0.9, 'width': 0.5, 'height': 0.5, 'action': 'blur'},
        ]
        # Must execute without exception
        redacted = redact_image(img, detections=[], ocr_words=[], manual_regions=bad_regions)
        self.assertIsNotNone(redacted)
        self.assertEqual(redacted.shape, (100, 200, 3))

    def test_automatic_plus_manual_overlap_handling(self):
        """Ensure automatic + manual overlap does not double-draw or corrupt pixels."""
        img = np.ones((100, 200, 3), dtype=np.uint8) * 255
        ocr_words = [{'text': '9876543210', 'x': 40, 'y': 20, 'w': 80, 'h': 20}]
        dets = [{'type': 'PHONE', 'value': '9876543210', 'decision': 'FULL_REDACT'}]
        # Manual region directly overlapping the phone number (x:40/200=0.2, y:20/100=0.2)
        manual_regions = [{'x': 0.2, 'y': 0.2, 'width': 0.4, 'height': 0.2, 'action': 'redact'}]

        out = redact_image(img, dets, ocr_words, manual_regions=manual_regions)
        self.assertIsNotNone(out)
        self.assertEqual(list(out[30, 80]), [0, 0, 0])


if __name__ == '__main__':
    unittest.main()

