# RoboArm Android wrapper

This folder contains a minimal Android app that opens your Flask-based RoboArm web UI inside a WebView.

## Build notes

1. Start the Flask server on your PC:
   - .\.venv\Scripts\python.exe app.py
2. Install the app on an Android phone or emulator.
3. The app will try to open http://127.0.0.1:5000/ on the device, which will not work directly on a phone unless the Flask server is reachable from that device.

For a real phone build, replace the URL with your PC's LAN IP, for example:

- http://192.168.1.50:5000/
