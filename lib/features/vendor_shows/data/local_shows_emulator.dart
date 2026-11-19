import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/repositories/shows_repository.dart';
import 'repositories/firestore_shows_repository.dart';

/// Call after local Auth initialization on the default demo Firebase app.
ShowsRepository createLocalShowsRepository() {
  final firestore = FirebaseFirestore.instance;
  firestore.settings = const Settings(persistenceEnabled: false);
  firestore.useFirestoreEmulator(
    '127.0.0.1',
    8180,
    automaticHostMapping: false,
  );
  return FirestoreShowsRepository(firestore);
}
