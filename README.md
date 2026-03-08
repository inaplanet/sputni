# AetherLink (Flutter + WebRTC)

AetherLink is a cross-platform Flutter app where one device runs as **Camera** (sends video) and another as **Monitor** (receives video). Signaling runs over secure WebSocket (`wss://`) and media is protected by WebRTC DTLS/SRTP.

## Architecture

- `lib/camera_view` and `lib/monitor_view`: UI and high-level orchestration.
- `lib/signaling`: typed signaling message model and WebSocket signaling client.
- `lib/webrtc`: peer connection, offer/answer exchange, ICE handling, media setup.
- `lib/config`: environment-driven app config and token helper.
- `lib/utils`: logging and shared error type.

## Signaling protocol

Messages are JSON with `{ "type": "...", "payload": { ... } }`:
- `join`
- `offer`
- `answer`
- `ice-candidate`
- `control` (`start`/`stop`)

## Requirements

- Flutter 3.19+ (Dart 3.3+)
- Android SDK / Xcode for target platforms
- A TLS signaling server (`wss://`)
- Optional TURN server for restrictive NATs

## Setup

```bash
flutter pub get
```

Provide runtime config using `--dart-define`:

```bash
flutter run \
  --dart-define=SIGNALING_URL=wss://your-signal.example/ws \
  --dart-define=ENABLE_TURN=true \
  --dart-define=STUN_URL=stun:stun.l.google.com:19302 \
  --dart-define=TURN_URL=turn:turn.example.com:3478 \
  --dart-define=TURN_USERNAME=user \
  --dart-define=TURN_PASSWORD=pass
```

## Android platform config

`android/app/src/main/AndroidManifest.xml` must include:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

If you use cleartext signaling for local dev only, add network security config. In production keep TLS (`wss://`).

## iOS platform config

`ios/Runner/Info.plist` should include:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to stream video.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required for optional audio.</string>
```

For App Transport Security, allow only secure endpoints where possible.

## Running roles

1. Launch app on device A and select **Start as Camera**.
2. Launch on device B and select **Start as Monitor**.
3. Use same room ID on both devices.
4. Camera sends `offer`; Monitor returns `answer`; both exchange ICE candidates.

## Testing

```bash
flutter test
```

Includes:
- Signaling message serialization/parsing tests.
- Scaffold test for peer connection state transitions (integration/device extension point).

## Notes

- TURN is optional and toggled by `ENABLE_TURN`.
- `DtlsSrtpKeyAgreement` is requested in peer connection options for encrypted media transport.
- Reconnection logic is implemented in the signaling client with bounded retries.
