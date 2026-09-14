import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/sipcount_app.dart';
import 'features/tracking/application/tracker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final tracker = await Tracker.start();
  runApp(SipcountApp(tracker: tracker));
}
