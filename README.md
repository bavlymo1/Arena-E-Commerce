# e_commerce_project

## Customer journey demo

```powershell
flutter run --flavor customer -t lib/main_customer_demo.dart
```

This explicit entry point uses local sample data and the labelled `demo-customer`
account. Discover, Details, Seats and Result use the implemented screens and
repository contracts. Sample bookings reset when the process restarts; they do
not authenticate, reserve real seats or write to Firebase. The normal Customer
and Vendor entry points still show setup pending.

The success show has 14:00 and 19:00 sessions. Other sample shows demonstrate
conflicts, a lost confirmation response with same-reference recovery, sold-out
seats and an unavailable session. Poster refresh uses existing show metadata or
explicit retry; an image-only change without a metadata signal is not a live
image subscription.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## ArenaPass local foundation

Android flavors have separate install IDs, app names and launcher icons:

- Customer: `com.arenapass.customer`, `lib/main_customer.dart`.
- Vendor: `com.arenapass.vendor`, `lib/main_vendor.dart`.

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --flavor customer -t lib/main_customer.dart
flutter build apk --debug --flavor vendor -t lib/main_vendor.dart
```

Supply the installed Android SDK through `ANDROID_HOME` if needed. The default
`main.dart` selects the native flavor; production entry points above are explicit.
The two isolated GetIt graphs register provider-owned StartupCubit factories and
use go_router. App teardown owns router/container disposal; Cubits ignore late
async completion after close.

This foundation intentionally displays **Setup pending**. Cloud configuration,
Firebase initialization, Customer authentication, Vendor enrollment and feature
routes are not implemented. Retry rechecks startup availability; it never grants
access or silently substitutes fake data. Tests inject startup checks directly.
No Firebase project, credentials, Google Services plugin or cloud resource is
created. Future auth/access route redirects depend on reviewed repositories and
must remain closed until configured. A build is not proof of side-by-side install
or device acceptance.
