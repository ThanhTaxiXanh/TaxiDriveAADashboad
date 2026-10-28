import 'package:flutter/widgets.dart';
import 'main.dart';

void startCar() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DashboardApp(car: true));
}
