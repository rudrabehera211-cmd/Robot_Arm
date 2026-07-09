# RoboArm Android App

## Setup

1. Open `RoboArmApp` folder in Android Studio
2. Sync Gradle (File → Sync Project with Gradle Files)
3. Update SDK path in `local.properties` if needed

## Build APK

### Debug APK
- Build → Build Bundle(s) / APK(s) → Build APK(s)
- Output: `app/build/outputs/apk/debug/app-debug.apk`

### Release APK
1. Build → Generate Signed Bundle/APK
2. Select APK → Next
3. Create keystore (first time) or select existing
4. Select release → Finish
- Output: `app/build/outputs/apk/release/app-release.apk`

## Usage

1. Run Flask server on your PC: `python app.py`
2. Install APK on phone
3. Enter your PC's IP: `http://192.168.1.100:5000`
4. Control robot arm from phone

## Notes

- Phone and PC must be on same WiFi network
- Find PC IP: `ipconfig` in terminal
- Default Flask port: 5000
