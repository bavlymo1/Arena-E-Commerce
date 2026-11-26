# Integration scenarios

Local Firebase Auth (`9099`) and Firestore (`8180`) integration suites runnable against `demo-arenapass`:

- `customer_auth_adapter_test.dart`: `FirebaseCustomerAuthRepository` register, stream, logout, invalid login, and error mapping.
- `customer_auth_journey_test.dart`: end-to-end Customer auth routing, logout cache clear, Back guard, and multi-UID isolation.
- `customer_firestore_reads_test.dart`: live Firestore show feed sorting, search, poster bytes, session updates, and delete -> unavailable transition.
- `customer_booking_emulator_test.dart`: atomic Customer booking, Vendor read-only map propagation, same-reference recovery, and concurrent contention race.
- `vendor_show_delete_emulator_test.dart`: multi-batch (`<= 3` pairs/batch) delete, customer unavailable transition, interrupted delete `resumeDeletes`, and idempotency.

Shared emulator helpers and the offline JPEG fixture live under `integration_test/support/` (`emulator_support.dart`, `poster_fixture.dart`). Run suites individually with `--flavor customer -d <device-id>` after forwarding emulator ports (`adb reverse tcp:9099 tcp:9099` and `adb reverse tcp:8180 tcp:8180`).
