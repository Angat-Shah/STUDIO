# Studio - Secure Video Player

A mobile application developed to provide secure video playback using watermarking and screenshot detection techniques to prevent content misuse, in various environments.

---

## Project Overview

This app focuses on protecting learning material through:

- Secure video playback with custom controls
- Dynamic watermark with timestamp
- Screenshot detection and response
- Mobile-first, user-friendly design

---

## Core Features

### 1. Custom Video Player
- Supports `.mp4` files and other various files like `mov`
- Playback controls: play, pause, seek bar, volume
- Fullscreen toggle
- Duration and current time display

### 2. Dynamic Watermarking
- Overlay includes username and current timestamp
- Automatically updates every 30 seconds
- Positioned centrally to avoid easy cropping
- Semi-transparent and responsive on all devices

### 3. Screenshot Protection
- Detects screenshot events (real device)
- Displays warning popup and pauses playback
- Logs total attempts in-session and displays on dashboard

---

## Secondary Features

### 4. Playback Restrictions
- Rewind limited to 10-second steps
- Fast-forward speed capped at 2x
- Toggle-based Secure Mode enables restrictions

### 5. Basic Security Indicators
- On-screen toggle indicators for protection status
- View watermark settings
- Screenshot attempt log for each session

---

## Tech Stack

- Framework: **Flutter**
- Language: **Dart**
- Key Plugins: `video_player`, `chewie`, `permission_handler`, `shared_preferences`

---

## Sample App Flow

1. **Home Screen** – Select video or use file picker
2. **Player Screen** – Video with watermark overlay and playback controls
3. **Settings Screen** – Customize watermark and toggle Secure Mode

---

## How to Run

1. Clone this repository.
2. Run `flutter pub get`.
3. Execute `flutter run`.

---

## Testing Screenshot Detection

1. Launch video playback on a device or simulator.
2. Attempt a screenshot — a warning popup should appear and the player will pause and a black screenshot will be captured.
3. Visit the Security Dashboard to see attempt logs.

---

## Known Limitations

- App stability is a little bit issue.
- Screen recording is not blocked currently.
- iOS support requires native implementation extensions.

---

## Architecture Decisions

- Followed modular folder structure with clear separation between UI, services, and state management
- Utilized `Stack` widgets for watermark overlays

---

## Improvements with More Time

- Add biometric lock for Secure Mode toggle
- Obfuscate watermark in recorded screen sessions
- Storage Implementation using Firebase.
