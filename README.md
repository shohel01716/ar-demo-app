# AR Demo App

A simple Flutter AR demo app using ARCore to display and interact with 3D objects.

## Features

- Opens device camera with ARCore
- Displays a 3D red ball (sphere) in AR space
- Ball appears 1 meter in front of the camera
- "Throw" button to animate the ball forward
- "Reset" button to return ball to initial position

## Requirements

- Flutter SDK (stable channel)
- Android device with ARCore support
- Android 7.0 (API level 24) or higher

## Setup

1. Install dependencies:
```bash
flutter pub get
```

2. Connect an ARCore-compatible Android device

3. Run the app:
```bash
flutter run
```

## Dependencies

- `arcore_flutter_plugin`: ARCore integration for Flutter
- `vector_math`: 3D vector mathematics

## Notes

- This is a proof-of-concept demo
- No realistic physics or collision detection
- Android only (ARCore requirement)
