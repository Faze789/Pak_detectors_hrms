# Pak Detectors HRMS

A human resource management system built with Flutter and Firebase, designed for Pak Detectors to manage employees, attendance, payroll, recruitment, and performance tracking — all from a single dashboard.

## Features

- **Role-based access** — Separate HR and Employee dashboards with scoped permissions
- **Attendance tracking** — Geofenced check-in/out with break tracking and automated absent marking via Cloud Functions
- **Leave management** — Full-day and half-day leave requests with HR approval workflow
- **Payroll** — Monthly payslip generation with salary breakdowns, allowances, deductions, and attendance-based adjustments
- **Recruitment** — Job postings with shareable public application links (no login required for applicants)
- **Performance** — Quarterly goal setting, weekly task tracking, and barrier reporting with push notifications
- **Multi-branch support** — Branch management with employee assignment and field duty mode
- **Meetings & notifications** — Meeting scheduling with FCM push notifications
- **Document management** — Employee document uploads with versioning

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) |
| State management | Provider (ChangeNotifier) |
| Routing | go_router |
| Backend | Firebase (Auth, Firestore, Storage, Messaging) |
| Cloud Functions | Node.js (scheduled absent marking, notification triggers) |
| PDF generation | pdf + printing packages |
| Location | Geolocator + Geocoding |

## Getting Started

### Prerequisites

- Flutter SDK `>=3.8.1`
- Firebase project with Firestore, Auth, Storage, and Messaging enabled
- Node.js (for deploying Cloud Functions)

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/Faze789/Pak_detectors_hrms.git
   cd Pak_detectors_hrms
   ```

2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase:
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to the respective platform folders
   - Update `lib/firebase_options.dart` if needed

4. Deploy Cloud Functions:
   ```bash
   cd functions
   npm install
   firebase deploy --only functions
   ```

5. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart              # App entry point, provider setup, routing
├── models/                # Data models (Firestore serialization)
├── services/              # Firebase operations and business logic
├── viewmodels/            # State management (ChangeNotifier classes)
├── views/                 # UI screens
│   ├── HR_views/          # HR dashboard, employee mgmt, payroll, recruitment
│   ├── employee_views/    # Employee dashboard, attendance, leaves, payslips
│   └── employee_tabs/     # Shared tab components for profile views
└── widgets/               # Reusable UI components

functions/
└── index.js               # Cloud Functions (absent marking, notifications)
```

## Cloud Functions

| Function | Schedule | Purpose |
|----------|----------|---------|
| `markAbsentAtCutoff` | 12:01 PM Mon–Fri (PKT) | Marks employees absent if not checked in by noon |
| `markAbsentHalfDay` | 2:01 PM Mon–Fri (PKT) | Catches first-half leave employees who didn't check in by 2 PM |
| `onBarrierCreated` | Firestore trigger | Sends FCM notifications when barriers are reported |

## License

This project is proprietary to Pak Detectors.
