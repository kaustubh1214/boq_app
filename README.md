# AV BOQ - Flutter demo (static)

Android demo of the AV Group BOQ & Material Management app. It runs fully offline on sample data
(no API, no database). Two roles: Store Manager and Site User (Tower A).

## Build (Codemagic)
`codemagic.yaml` generates the Android project files at build time (`flutter create`), then builds a release APK.
Download the APK from the finished build page and install it on an Android phone.

## What is in the demo
- Site User: request material (default unit, change unit, live conversion), my requests with Undo / Repeat,
  receive deliveries ("Received all OK"), log consumption against site stock.
- Store Manager: badges for pending work, approve & issue in one tap (bulk select, short-stock warning, reject),
  central stock with low-stock flags and value, inward GRN with unit conversion and weighted-average rate.

Real API integration comes later; `lib/data.dart` is the only place that would be replaced.
