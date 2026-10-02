# Store Dashboard PDF Preview / Download Fix

Changes:
- Category names remain human-readable on the Store Dashboard (for example `rice_meals` -> `Rice Meals`).
- Main dashboard action is now **VIEW PDF**.
- PDF download is moved into the PDF preview modal as a download icon/action.
- The preview no longer reuses a previously generated `Uint8List`. It generates a fresh PDF buffer on every preview/download request to avoid Flutter Web `DataCloneError: An ArrayBuffer is detached and could not be cloned` failures.
- Web download uses a browser PDF download link; non-web platforms fall back to the existing PDF share flow.

Validation required locally:

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Manual check:
1. Open Store Dashboard.
2. Confirm category names are formatted as display names.
3. Click **VIEW PDF**.
4. Confirm the PDF preview renders without the red DataCloneError screen.
5. Use the download icon inside the modal.
6. Confirm the browser downloads `store_dashboard_YYYY-MM-DD_YYYY-MM-DD.pdf`.
7. Test print and share actions as well.

No GitHub commit/push was made.
