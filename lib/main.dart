import 'dart:async';

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'ui/mobile_tina_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppController controller = AppController();
  await controller.initialize();
  runApp(MobileTinaApp(controller: controller));
}
