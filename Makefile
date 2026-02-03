.PHONY: backend-test backend-run android-run android-build ci

backend-test:
	cd backend && python -m pytest

backend-run:
	cd backend && python -m uvicorn main:app --reload

android-run:
	cd android-app && flutter run

android-build:
	cd android-app && flutter build apk

ci: backend-test
