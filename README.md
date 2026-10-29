# AV BOQ — Android app

The Android app for AV Group's BOQ & material management. It opens the **live** AV BOQ web app
(same screens, same logins, same data as on a computer) and adds the phone-only parts:

| Phone feature | How |
|---|---|
| Scan the gate-pass QR | native camera scanner (`lib/scanner.dart`) |
| Gate-pass PDF / Excel exports | saved in the app, opened in the phone's viewer, **Share** to WhatsApp |
| Invoice photo / CSV upload | "Take a photo" or "Choose from phone" |
| Back button | closes an open dialog first, then goes back a screen |
| Server offline | clear "Can't reach the BOQ server" screen with **Try again** |
| New server address | **Server settings** (on the offline screen) — no rebuild needed |

The web side of the bridge is `boq-ui/src/lib/native.ts` in the main BOQ repo (channel `AvBoqApp`).

## Server

Default address: `https://keturah-incontestable-subaxially.ngrok-free.dev` (`lib/config.dart`).
On the office laptop: Docker stack running (`docker compose up -d` in `boq-management/`) and

```bash
ngrok http --url=keturah-incontestable-subaxially.ngrok-free.dev http://127.0.0.2:3100
```

The app sends its own user agent (`AVBOQ-Android/1.0`), so ngrok's free-plan warning page is skipped.

## Build (Codemagic)

Workflow **AV BOQ Android app** in `codemagic.yaml`: generates the Android project, adds internet +
camera permissions and the app icon, checks the code, and builds `app-release.apk` (download it from the
build's Artifacts and install on the phone; allow "install unknown apps" once).
