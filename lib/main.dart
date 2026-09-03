import 'dart:async';

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'services/protected_assets.dart';
import 'ui/mobile_tina_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ProtectedAssets.initialize();
  final AppController controller = AppController();
  await controller.initialize();
  runApp(MobileTinaApp(controller: controller));
}
