"""Unit tests for conditional OCR Pass 2 selection."""

import unittest
from unittest.mock import Mock, patch

import numpy as np

from modules.ocr_engine import _extract_words_and_text
from modules import ocr_engine


def _ocr_data(words, confidence=80, start_x=10):
    count = len(words)
    return {
        'text': list(words),
        'conf': [confidence] * count,
        'block_num': [1] * count,
        'par_num': [1] * count,
        'line_num': [1] * count,
        'left': [start_x + i * 20 for i in range(count)],
        'top': [10] * count,
        'width': [15] * count,
        'height': [10] * count,
    }


class TestConditionalPass2(unittest.TestCase):
    def setUp(self):
        self.processed = np.zeros((100, 400), dtype=np.uint8)
        self.original = np.zeros((100, 400, 3), dtype=np.uint8)
        self.p1_words = [f'word{i}' for i in range(15)]

    def _run(self, p1_data, detections=None, p2_data=None, p1_text_fallback=''):
        detections = detections or []
        calls = []

        def detector(text):
            calls.append(text)
            return {'detections': detections, 'stats': {'ner_detections': 0}}

        data_results = [p1_data]
        if p2_data is not None:
            data_results.append(p2_data)

        with patch('modules.ocr_engine.pytesseract.image_to_data', side_effect=data_results) as ocr_mock, \
             patch('modules.ocr_engine.pytesseract.image_to_string', return_value=p1_text_fallback):
            result = _extract_words_and_text(
                self.processed, self.original, detection_fn=detector
            )
        return result, calls, ocr_mock

    def test_enough_words_and_pii_skips_pass2(self):
        result, detector_calls, ocr_mock = self._run(
            _ocr_data(self.p1_words, confidence=50), detections=[{'type': 'EMAIL'}]
        )
        self.assertEqual(ocr_mock.call_count, 1)
        self.assertEqual(len(detector_calls), 1)
        self.assertEqual(len(result[0]), 15)
        self.assertEqual(result[2]['detections'][0]['type'], 'EMAIL')

    def test_fourteen_words_runs_but_fifteen_words_can_skip(self):
        _, _, fourteen_ocr = self._run(_ocr_data(self.p1_words[:14], confidence=70))
        _, _, fifteen_ocr = self._run(_ocr_data(self.p1_words, confidence=70))
        self.assertEqual(fourteen_ocr.call_count, 2)
        self.assertEqual(fifteen_ocr.call_count, 1)

    def test_confidence_boundary_without_pii(self):
        below_data = _ocr_data([f'word{i}' for i in range(100)])
        below_data['conf'] = [64] * 10 + [65] * 90  # Average confidence is exactly 0.649.
        _, _, below_ocr = self._run(below_data)
        _, _, boundary_ocr = self._run(_ocr_data(self.p1_words, confidence=65))
        self.assertEqual(below_ocr.call_count, 2)
        self.assertEqual(boundary_ocr.call_count, 1)

    def test_enough_words_and_high_confidence_skips_pass2(self):
        result, _, ocr_mock = self._run(_ocr_data(self.p1_words, confidence=70))
        self.assertEqual(ocr_mock.call_count, 1)
        self.assertEqual(len(result[0]), 15)

    def test_insufficient_words_runs_pass2(self):
        pass2 = _ocr_data(['sparse-token'], confidence=90, start_x=350)
        result, _, ocr_mock = self._run(_ocr_data(self.p1_words[:4]), p2_data=pass2)
        self.assertEqual(ocr_mock.call_count, 2)
        self.assertEqual(result[1], ' '.join(self.p1_words[:4]))
        self.assertIn('sparse-token', [word['text'] for word in result[0]])

    def test_low_confidence_without_pii_runs_pass2(self):
        pass2 = _ocr_data(['sparse-token'], confidence=90, start_x=350)
        result, _, ocr_mock = self._run(
            _ocr_data(self.p1_words, confidence=50), p2_data=pass2
        )
        self.assertEqual(ocr_mock.call_count, 2)
        self.assertIn('sparse-token', [word['text'] for word in result[0]])

    def test_empty_ocr_runs_pass2(self):
        empty = _ocr_data([])
        pass2 = _ocr_data(['recovered'], confidence=90)
        result, _, ocr_mock = self._run(empty, p2_data=pass2)
        self.assertEqual(ocr_mock.call_count, 2)
        self.assertEqual(result[1], '')
        self.assertEqual([word['text'] for word in result[0]], ['recovered'])

    def test_detection_result_is_reused_without_a_second_detection_call(self):
        detector = Mock(return_value={'detections': [{'type': 'PAN'}], 'stats': {}})
        with patch(
            'modules.ocr_engine.pytesseract.image_to_data',
            return_value=_ocr_data(self.p1_words),
        ) as ocr_mock:
            result = _extract_words_and_text(
                self.processed, self.original, detection_fn=detector
            )
        detector.assert_called_once()
        self.assertEqual(ocr_mock.call_count, 1)
        self.assertEqual(result[2]['detections'][0]['type'], 'PAN')

    def _merge(self, pass1, pass2):
        return self._run(_ocr_data([pass1['text']], confidence=int(pass1['confidence'] * 100),
                                   start_x=pass1.get('x', 10)),
                         p2_data=_ocr_data([pass2['text']], confidence=int(pass2['confidence'] * 100),
                                           start_x=pass2.get('x', 10)))[0][0]

    def test_overlapping_numeric_pass2_replaces_nonnumeric_pass1(self):
        words = self._merge({'text': 'esr', 'confidence': .90}, {'text': '6081', 'confidence': .30})
        self.assertEqual([word['text'] for word in words], ['6081'])

    def test_overlapping_higher_confidence_pass2_replaces_pass1(self):
        words = self._merge({'text': 'token', 'confidence': .50}, {'text': 'better', 'confidence': .70})
        self.assertEqual([word['text'] for word in words], ['better'])

    def test_overlapping_pass2_below_replacement_threshold_keeps_pass1(self):
        words = self._merge({'text': 'token', 'confidence': .50}, {'text': 'other', 'confidence': .65})
        self.assertEqual([word['text'] for word in words], ['token'])

    def test_non_overlapping_pass2_is_appended_and_coordinates_are_scaled(self):
        p2 = _ocr_data(['extra'], confidence=90, start_x=300)
        with patch('modules.ocr_engine.pytesseract.image_to_data',
                   side_effect=[_ocr_data(['base'], confidence=50), p2]) as ocr_mock, \
             patch('modules.ocr_engine.cv2.resize', return_value=np.zeros((150, 600), dtype=np.uint8)) as resize:
            words, _, _, _ = _extract_words_and_text(self.processed, self.original)
        self.assertEqual(ocr_mock.call_count, 2)
        resize.assert_called_once()
        extra = next(word for word in words if word['text'] == 'extra')
        self.assertEqual((extra['x'], extra['w']), (200, 10))

    def test_overlapping_duplicate_token_is_not_added_or_deduplicated_elsewhere(self):
        words = self._merge({'text': 'same', 'confidence': .90}, {'text': 'same', 'confidence': .90})
        self.assertEqual([word['text'] for word in words], ['same'])

    def test_pdf_pages_make_independent_pass2_decisions_and_detect_once_each(self):
        class Pix:
            width, height, n = 2, 2, 3
            samples = bytes([0] * 12)

        class Page:
            def get_pixmap(self, dpi):
                return Pix()

        class Doc:
            def __len__(self): return 2
            def __getitem__(self, index): return Page()
            def close(self): pass

        detections = []
        def detector(text):
            detections.append(text)
            return {'detections': [{'type': 'EMAIL'}] if len(text.split()) >= 15 else [], 'stats': {}}

        page1 = _ocr_data(self.p1_words, confidence=50)
        page2 = _ocr_data(['few', 'words'], confidence=50)
        p2 = _ocr_data(['recovered'], confidence=90, start_x=350)
        with patch.object(ocr_engine.pymupdf, 'open', return_value=Doc()), \
             patch.object(ocr_engine, 'preprocess_cv2_image', side_effect=[(self.processed, self.original)] * 2), \
             patch('modules.ocr_engine.pytesseract.image_to_data', side_effect=[page1, page2, p2]) as ocr_mock:
            pages = ocr_engine.get_pdf_pages_data('unused.pdf', detection_fn=detector)
        self.assertEqual(len(pages), 2)
        self.assertEqual(ocr_mock.call_count, 3)  # Page 1 Pass 1; page 2 Pass 1 and Pass 2.
        self.assertEqual(len(detections), 2)
        self.assertEqual(pages[0]['detection_result']['detections'][0]['type'], 'EMAIL')
        self.assertIn('recovered', [word['text'] for word in pages[1]['words']])


if __name__ == '__main__':
    unittest.main()
