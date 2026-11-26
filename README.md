
<h1 align="center">ArenaPass</h1>

<p align="center">
  Android event booking and management platform built with Flutter and Firebase.
  One codebase, two applications for customers and vendors.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=flat-square&logo=firebase&logoColor=black" alt="Firebase" />
  <img src="https://img.shields.io/badge/Android-3DDC84?style=flat-square&logo=android&logoColor=white" alt="Android" />
</p>

---

## Features

### Customer App

- Email and password authentication.
- Real-time event discovery and search.
- Show details and session selection.
- Interactive 47-seat map with an accessible row-list mode.
- Real-time seat availability.
- Atomic seat reservations with conflict handling.
- Booking confirmation and recovery.
- Light and dark themes.

### Vendor App

- Secure device enrollment.
- Show creation and management.
- Event posters using the camera or gallery.
- Up to five sessions per show.
- Real-time, read-only seat maps.
- Booking updates and local notifications.
- Restart-safe show deletion.
- Light and dark themes.

## Screenshots

<h3 align="center">Customer App</h3>

<div align="center">

| Discover | Show Details | Seat Selection |
| :---: | :---: | :---: |
| Coming soon | Coming soon | Coming soon |

</div>

<h3 align="center">Vendor App</h3>

<div align="center">

| My Shows | Add Show | Booking Updates |
| :---: | :---: | :---: |
| Coming soon | Coming soon | Coming soon |

</div>

## Architecture

The project follows a feature-first architecture, separating presentation, domain and data responsibilities where needed.

Cubit handles state management, GetIt manages dependency registration, and GoRouter handles navigation. Both applications share seating components, reusable widgets and domain contracts.

<div align="center">

<pre>
    ┌────────────────┐       ┌────────────────┐
    │  Customer App  │       │   Vendor App   │
    └───────┬────────┘       └───────┬────────┘
            │                        │
    ┌───────▼────────┐       ┌───────▼────────┐
    │ Customer Router│       │  Vendor Router │
    └───────┬────────┘       └───────┬────────┘
            │                        │
            └───────────┬────────────┘
                        │
               ┌────────▼────────┐
               │ Feature Modules │
               └────────┬────────┘
                        │
               ┌────────▼────────┐
               │  Presentation   │
               │ Screens / Cubits│
               └────────┬────────┘
                        │
               ┌────────▼────────┐
               │     Domain      │
               │    Contracts    │
               └─────────────────┘
                        ▲
                        │
               ┌────────┴────────┐
               │      Data       │
               │  Repositories   │
               └────────┬────────┘
                        │
               ┌────────▼────────┐
               │Firebase Services│
               └─────────────────┘
</pre>

</div>

Dependencies are provided through constructor injection, with GetIt confined to application composition. Data implementations depend on domain contracts rather than the other way around.

### Project Structure

```text
lib/
├── app/
│   ├── customer/
│   ├── vendor/
│   ├── di/
│   ├── router/
│   ├── startup/
│   └── theme/
├── core/
│   └── formatting/
├── features/
│   ├── booking/
│   ├── customer_auth/
│   ├── discovery/
│   ├── vendor_access/
│   ├── vendor_notifications/
│   └── vendor_shows/
├── shared/
│   ├── seating/
│   └── widgets/
├── firebase_options_customer.dart
├── firebase_options_vendor.dart
├── main_customer.dart
├── main_vendor.dart
└── main.dart

firebase/
test/
integration_test/
android/
```

## Tech Stack

<div align="center">

| Technology | Usage |
| :--- | :--- |
| Flutter & Dart | Application development |
| Cubit | State management |
| Equatable | Value equality |
| GetIt | Dependency injection |
| GoRouter | Navigation |
| Firebase Authentication | Authentication |
| Cloud Firestore | Real-time data and persistence |
| Firestore Security Rules | Authorization and validation |
| Image Picker | Event posters |
| Flutter Local Notifications | Vendor alerts |
| SharedPreferences | Local persistence |

</div>

## Booking System

Each show supports up to five sessions, with 47 seats per session.

<div align="center">

<pre>
                  ARENA FLOOR
      ─────────────────────────────────

      01 02 03 04  │  05 06 07 08 09
      10 11 12 13  │  14 15 16 17 18
      19 20 21 22  │  23 24 25 26 27
      28 29 30 31  │  32 33 34 35 36

      37 38 39 40 41 42 43 44 45 46 47
</pre>

</div>

Booking requests are processed through atomic Firestore transactions to prevent double booking. A successful reservation updates the booking, session, show and booking event documents together.

Vendors receive booking updates through Firestore streams without manually refreshing the application.

### Booking Flow

<div align="center">

<pre>
             Customer selects seats
                       │
                Confirms booking
                       │
                 Booking Cubit
                       │
               Booking Repository
                       │
              Firestore Transaction
                       │
          ┌────────────┼────────────┐
          │            │            │
      Confirmed     Conflict     Uncertain
          │            │            │
    Booking Result   Seat Update   Recovery
          │
          ▼
    Committed Booking Event
          │
     Vendor Updates
          │
   Local Notification
</pre>

</div>

Uncertain transaction outcomes are handled through authoritative booking recovery checks. Vendor notifications originate from committed booking events in Firestore.

## Getting Started

### Prerequisites

- Flutter SDK
- Android SDK
- Android device or emulator
- Java 21, Node.js 22 and Firebase CLI for local backend testing

### Installation

```bash
git clone -b dev https://github.com/bavlymo1/Arena-E-Commerce.git
cd Arena-E-Commerce
flutter pub get
```

### Run the Customer App

```bash
flutter run --flavor customer -t lib/main_customer.dart
```

### Run the Vendor App

```bash
flutter run --flavor vendor -t lib/main_vendor.dart
```

For explicitly authorized live Vendor operation:

```bash
flutter run --flavor vendor -t lib/main_vendor.dart --dart-define=VENDOR_D01_APPROVED=true
```

Vendor devices must also be enrolled by an administrator. The startup flag does not bypass Firebase authorization or Security Rules.

### Build Android APKs

```bash
# Customer
flutter build apk --release --flavor customer -t lib/main_customer.dart

# Vendor
flutter build apk --release --flavor vendor -t lib/main_vendor.dart
```

For authorized live Vendor builds, include the approved startup flag.

Generated APKs are available under:

```text
build/app/outputs/flutter-apk/
```

## Roadmap

### Tier 1

- [x] Customer authentication
- [x] Event discovery and search
- [x] Seat selection and booking
- [x] Vendor show management
- [x] Real-time booking updates
- [x] Local notifications
- [x] Architecture and routing organization
- [ ] Final multi-device acceptance and release approval

### Tier 2

- [ ] Booking history
- [ ] Extended account management
- [ ] Booking cancellation
- [ ] QR tickets and attendance verification
- [ ] Offline ticket access
- [ ] Persistent booking recovery
- [ ] Background push notification evaluation
- [ ] UI/UX improvements
- [ ] Application size and performance optimization

## Project Status

Tier 1 core functionality is implemented and available on the `dev` branch.

Final multi-device testing, Android 13+ notification permission verification, instructor approval, and team sign-off remain pending.
