import os

import pytest

from main import _safe_filename, _validate_content_type
from pdf_generator import generate_redacted_pdf


def test_safe_filename_allows_supported_extension():
    name = _safe_filename("sample.pdf")
    assert name.endswith(".pdf")


def test_safe_filename_rejects_unsupported_extension():
    with pytest.raises(Exception):
        _safe_filename("sample.exe")


def test_generate_redacted_pdf_creates_file(tmp_path):
    output_path = tmp_path / "out.pdf"
    result = generate_redacted_pdf("Hello World", output_path=str(output_path))
    assert result == str(output_path)
    assert os.path.exists(result)


def test_validate_content_type_allows_known():
    _validate_content_type("application/pdf")


def test_validate_content_type_rejects_unknown():
    with pytest.raises(Exception):
        _validate_content_type("application/x-msdownload")
