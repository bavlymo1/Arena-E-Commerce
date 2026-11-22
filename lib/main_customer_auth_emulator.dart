import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'app/customer/customer_app.dart';
import 'app/di/customer_registration.dart';
import 'features/customer_auth/data/local_auth_emulator.dart';
import 'features/vendor_shows/data/local_shows_emulator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(createCustomerApp(services: await createLocalCustomerServices()));
}

Future<GetIt> createLocalCustomerServices() async {
  final authRepository = await createLocalAuthRepository();
  final shows = createLocalShowsRepository();
  return createLiveCustomerServices(
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
    authRepository: authRepository,
    showsRepository: shows,
  );
}
