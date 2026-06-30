<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.10+-0175C2?logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/Supabase-BaaS-3FCF8E?logo=supabase&logoColor=white" alt="Supabase">
  <img src="https://img.shields.io/badge/Gemini_2.5_Flash-AI-4285F4?logo=google&logoColor=white" alt="Gemini">
  <img src="https://img.shields.io/badge/MediaPipe-Pose-FF6F00?logo=google&logoColor=white" alt="MediaPipe">
  <img src="https://img.shields.io/badge/ML_Kit-Pose-4285F4?logo=google&logoColor=white" alt="ML Kit">
</p>

# 🩺 PhysioCare — AI-Powered Physiotherapy Platform

**PhysioCare** is a cross-platform (Web, Android, iOS) physiotherapy application built with **Flutter** that uses **real-time AI pose detection** to guide patients through rehabilitation exercises. It connects patients with their physiotherapists, tracks exercise progress, generates AI-powered clinical reports, and manages appointment scheduling — all in one app.

---

## 📸 How It Works

```
Patient opens app → Starts assigned exercise → Camera activates
→ AI detects body landmarks in real-time → Calculates joint angles
→ Counts reps via state machine → Provides live voice + text feedback
→ Saves session data → Generates AI clinical report (Gemini 2.5 Flash)
```

---

## 🏗️ Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Frontend** | Flutter & Dart (SDK ^3.10) | Cross-platform UI (Web, Android, iOS) |
| **Backend (BaaS)** | Supabase (PostgreSQL + Auth) | Database, authentication, real-time subscriptions |
| **AI / LLM** | Google Gemini 2.5 Flash | AI-generated clinical progress summaries |
| **Pose Detection (Web)** | MediaPipe Pose (JS) | 33-point body landmark detection via webcam |
| **Pose Detection (Mobile)** | Google ML Kit Pose Detection | Native on-device pose estimation (iOS/Android) |
| **Voice Feedback** | flutter_tts | Text-to-speech exercise guidance |
| **Reports** | pdf + printing packages | PDF report generation and export |
| **HTTP** | http package | REST API calls to Gemini |

---

## ✨ Features

### 🔐 Authentication & Roles
- Email/password signup & login via Supabase Auth
- **Dual-role registration** — Patient or Therapist
- Patients select their assigned therapist during registration
- Role-based routing to Patient or Therapist portal

### 🏠 Patient Portal
- **Dashboard** — Greeting, patient ID, assigned therapist, today's exercises, completion stats
- **My Exercises** — All assigned exercises with search, filter (Active / Upcoming / Completed), and auto-expiry
- **Session History** — Past exercise logs with reps, duration, and accuracy
- **Progress Reports** — AI-generated clinical summaries with PDF export

### 🩺 Therapist Portal
- **Dashboard** — Patient list with search and per-patient session summaries
- **Patient Detail View** — Profile, assigned exercises, session reports, pain alerts, feedback history
- **Assign Exercises** — Set exercise type, target reps, sets, sessions/day, date range
- **Write Feedback** — Submit clinical text feedback stored per patient

### 🏋️ AI-Powered Exercise Sessions (Core Feature)
- **5 supported exercises**: Bicep Curl, Side Raise, Squats, Standing Hip Abduction, Seated Knee Extension
- **Real-time pose detection** — MediaPipe (web) / ML Kit (mobile) producing 33 body landmarks
- **Joint angle calculation** — Dot-product formula on landmark triplets
- **State-machine rep counting** — `down → holding → up_done` with configurable angle thresholds
- **Timed hold validation** — e.g., 3-second isometric hold for Bicep Curls before counting a rep
- **Live feedback** — On-screen messages: *"Hold it..."*, *"Curl higher"*, *"Dropped early!"*, *"Nice rep!"*
- **Text-to-Speech** — Spoken audio cues for hands-free guidance
- **Milestone announcements** — *"Halfway there!"*, *"Last rep!"*, *"Session complete!"*
- **Skeleton overlay** — Real-time pose skeleton drawn on camera canvas
- **YouTube reference videos** — Embedded rehab-focused demo videos per exercise
- **Session persistence** — Reps, duration, accuracy saved to Supabase

### 🚨 Pain Alert System
- Patient can trigger a pain alert mid-exercise with severity level + message
- **Re-trigger throttling** — Updates existing alert if sent within 3 minutes
- **Offline retry queue** — Failed alerts retried automatically (30 attempts × 10s = 5 min window)
- Therapist views active pain alerts in patient detail screen

### 📅 Appointment Booking & Scheduling
- **Therapist availability management** — Weekly time windows with configurable slot duration
- **Blocked dates** — Therapists can block specific dates (holidays, leave) with reason
- **Calendar-based booking** — Patients browse available dates → pick time slot → submit with optional query
- **Appointment lifecycle** — `pending → confirmed / rejected / cancelled` with cancellation tracking
- **Therapist bookings view** — Confirm/reject incoming requests with notes

### 🔔 Notifications
- In-app notification feed for appointment updates
- Individual and bulk "mark all read" functionality

### 📊 Report Generation & AI Summaries
- **Report data aggregation** — Total sessions, reps, minutes, avg accuracy, best session, progress trend
- **Period filtering** — Weekly / Monthly / All Time
- **Gemini AI summary** — 3–4 sentence clinical progress note generated via Gemini 2.5 Flash REST API
- **Graceful fallback** — Local template-based summary if API key is missing or network fails
- **PDF export** — Formatted clinical report with patient info, stats, and AI summary

---

## 🧮 Technical Approach

### Pose Detection Pipeline
```
Camera Feed → Platform-Specific Model → 33 Landmarks → UnifiedPose
    ├─ Web:    MediaPipe Pose (JS interop, modelComplexity: 1)
    └─ Mobile: Google ML Kit Pose Detection (on-device)
```

### Exercise Classification
Keyword-based mapping from therapist-assigned exercise title → `ExerciseType` enum:
| Keyword Match | Exercise Type | Tracked Joints |
|---|---|---|
| `bicep` or `curl` | Bicep Curl | Shoulder → Elbow → Wrist |
| `side` or `raise` | Side Raise | Hip → Shoulder → Wrist |
| `squat` | Squats | Hip → Knee → Ankle |
| `abduction` | Standing Hip Abduction | Shoulder → Hip → Ankle |
| `knee` | Seated Knee Extension | Hip → Knee → Ankle |

### Joint Angle Calculation
Uses the **dot product formula** on 2D landmark coordinates:

```
cos(θ) = (BA⃗ · BC⃗) / (|BA⃗| × |BC⃗|)
angle = arccos(cos(θ)) × (180 / π)
```

### Rep Counting State Machine
Each exercise uses threshold-driven state transitions:
```
"down" ──(angle < upThreshold)──► "holding" ──(held ≥ 3s)──► "up_done"
  ▲                                                              │
  └─────────────(angle > downThreshold)────── rep counted! ◄─────┘
```

---

## 📁 Project Structure

```
PhysioCare-New/
├── apps/
│   └── physiocare_flutter/
│       ├── lib/
│       │   ├── app/                    # App widget & theme
│       │   ├── config/                 # Supabase config & environment keys
│       │   ├── core/
│       │   │   ├── routes/             # Named route definitions
│       │   │   ├── services/           # Core service layer
│       │   │   └── utils/              # Exercise status utilities
│       │   ├── data/
│       │   │   └── services/           # Data services (auth, profile, exercise,
│       │   │                           #   session, plan, therapist, pain alert)
│       │   ├── features/
│       │   │   ├── auth/               # Landing, Login, Register screens
│       │   │   ├── patient/            # Patient home, exercises, session reports
│       │   │   ├── therapist/          # Therapist home, patient detail view
│       │   │   ├── pose/
│       │   │   │   ├── pose_detector/  # Camera views, MediaPipe/ML Kit bridges,
│       │   │   │   │                   #   exercise logic classes, painters
│       │   │   │   ├── angle_math/     # Joint angle utilities
│       │   │   │   ├── feedback_engine/# Milestone announcements
│       │   │   │   ├── rep_counter/    # Platform-specific rep counters
│       │   │   │   ├── session/        # Exercise session orchestrator
│       │   │   │   └── session_runtime/# Session controller
│       │   │   ├── appointments/       # Booking, availability, notifications
│       │   │   └── reports/            # Report screens, models, services,
│       │   │                           #   AI summary, PDF generator
│       │   └── main.dart               # Entry point
│       ├── web/                        # Web-specific assets (MediaPipe JS)
│       ├── android/                    # Android platform config
│       ├── ios/                        # iOS platform config
│       └── pubspec.yaml                # Dependencies
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** ≥ 3.10 — [Install Flutter](https://docs.flutter.dev/get-started/install)
- **Supabase Project** — [Create one at supabase.com](https://supabase.com)
- **Gemini API Key** (optional) — [Get a free key from AI Studio](https://aistudio.google.com)
- **Chrome** (for web) or an emulator/device (for mobile)

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/PhysioCare-New.git
cd PhysioCare-New/apps/physiocare_flutter
```

### 2. Configure Environment

Copy the example env file and add your credentials:

```bash
cp lib/config/env.dart.example lib/config/env.dart
```

Then edit `lib/config/env.dart`:

```dart
class Env {
  static const String supabaseUrl = "YOUR_SUPABASE_URL";
  static const String supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY";
  static const String geminiApiKey = "YOUR_GEMINI_API_KEY"; // optional
}
```

> **Note:** The Gemini API key is optional. If omitted, AI summaries will fall back to a local template-based generator.

### 3. Set Up Supabase Database

Create the following tables in your Supabase project:

| Table | Purpose |
|---|---|
| `profiles` | User profiles (name, role, contact, condition, assigned_therapist_id, display_id) |
| `exercises` | Exercise catalog (title, description) |
| `assigned_exercises` | Therapist → Patient exercise assignments (reps, sets, dates, status) |
| `session_reports` | Per-session results (reps_done, duration_seconds, accuracy, exercise_title) |
| `therapist_feedback` | Clinical text feedback from therapist to patient |
| `reports` | Generated report data |
| `pain_alerts` | In-session pain alerts (patient_id, therapist_id, pain_level, status) |
| `appointments` | Booking records (patient_id, therapist_id, date, start/end time, status) |
| `therapist_availability` | Weekly availability windows (day_of_week, start/end time, slot_duration) |
| `therapist_blocked_dates` | Blocked dates (date, reason) |
| `notifications` | In-app notification records |

### 4. Install Dependencies

```bash
flutter pub get
```

### 5. Run the App

**Web (recommended for development):**
```bash
flutter run -d chrome
```

**Android:**
```bash
flutter run -d android
```

**iOS:**
```bash
flutter run -d ios
```

---

## 🧪 Supported Exercises

| Exercise | Body Region | Key Landmarks | Up Threshold | Down Threshold |
|---|---|---|---|---|
| **Bicep Curl** | Upper body | Shoulder, Elbow, Wrist | < 55° | > 155° |
| **Side Raise** | Upper body | Hip, Shoulder, Wrist | Custom | Custom |
| **Squats** | Lower body | Hip, Knee, Ankle | > 160° | < 110° |
| **Standing Hip Abduction** | Lower body | Shoulder, Hip, Ankle | Custom | Custom |
| **Seated Knee Extension** | Lower body | Hip, Knee, Ankle | Custom | Custom |

---

## 🔧 Key Dependencies

```yaml
dependencies:
  flutter: sdk
  supabase_flutter: ^2.12.0          # Backend & Auth
  camera: ^0.11.0+2                  # Device camera access
  google_mlkit_pose_detection: ^0.12.1 # Mobile pose detection
  google_mlkit_commons: ^0.8.1       # ML Kit shared utilities
  web: ^1.0.0                        # Web platform APIs
  flutter_tts: ^4.2.0                # Text-to-speech
  pdf: ^3.10.8                       # PDF generation
  printing: ^5.12.0                  # PDF printing/sharing
  http: ^1.2.1                       # HTTP client (Gemini API)
```

---

## 🏛️ Architecture Overview

```
┌──────────────────────────────────────────────────────┐
│                    Flutter App                        │
│  ┌──────────┐  ┌──────────┐  ┌────────────────────┐ │
│  │   Auth    │  │  Patient  │  │    Therapist       │ │
│  │  Module   │  │  Portal   │  │    Portal          │ │
│  └────┬─────┘  └────┬─────┘  └────────┬───────────┘ │
│       │              │                 │              │
│  ┌────▼──────────────▼─────────────────▼───────────┐ │
│  │              Pose Detection Engine               │ │
│  │   MediaPipe (Web) ◄──► ML Kit (Mobile)          │ │
│  │        ↓                    ↓                    │ │
│  │           UnifiedPose + Angle Math               │ │
│  │        ↓                    ↓                    │ │
│  │     Exercise Logic (State Machine + Rep Count)   │ │
│  │        ↓                    ↓                    │ │
│  │   Real-Time Feedback (Text + TTS)               │ │
│  └──────────────────┬──────────────────────────────┘ │
│                     │                                 │
│  ┌──────────────────▼──────────────────────────────┐ │
│  │              Data / Service Layer                │ │
│  │  Auth │ Profile │ Exercise │ Session │ Reports   │ │
│  └──────────────────┬──────────────────────────────┘ │
└─────────────────────┼────────────────────────────────┘
                      │
          ┌───────────▼───────────┐
          │   Supabase (Cloud)    │
          │  PostgreSQL + Auth    │
          └───────────────────────┘
                      │
          ┌───────────▼───────────┐
          │  Gemini 2.5 Flash API │
          │  (AI Report Summary)  │
          └───────────────────────┘
```

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -m 'Add your feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Open a Pull Request

---

## 📄 License

This project is for educational and research purposes.

---

## 👥 Acknowledgments

- [Flutter](https://flutter.dev/) — Cross-platform UI framework
- [Supabase](https://supabase.com/) — Open-source Firebase alternative
- [MediaPipe](https://ai.google.dev/edge/mediapipe/solutions/vision/pose_landmarker) — On-device ML for pose detection
- [Google ML Kit](https://developers.google.com/ml-kit/vision/pose-detection) — Mobile pose detection
- [Google Gemini](https://ai.google.dev/) — Generative AI for clinical summaries
