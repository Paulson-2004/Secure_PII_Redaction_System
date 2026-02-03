.PHONY: test lint run ci

test:
	python -m pytest

lint:
	python -m pytest -q

run:
	python -m uvicorn main:app --reload

ci:
	python -m pytest
