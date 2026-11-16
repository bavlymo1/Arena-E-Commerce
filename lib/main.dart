import 'package:flutter/services.dart';

import 'main_customer.dart' as customer;
import 'main_vendor.dart' as vendor;

void main() {
  if (appFlavor == 'vendor') {
    vendor.main();
  } else {
    customer.main();
  }
}
