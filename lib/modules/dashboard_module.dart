import 'package:flutter/material.dart';

abstract class DashboardModule {
  String get id;
  String get title;
  IconData get icon;
  Widget buildPanel(BuildContext context);
  Widget buildSettings(BuildContext context);
}

class DashboardModules {
  final Map<String, DashboardModule> _items = {};
  Iterable<DashboardModule> get items => _items.values;
  void register(DashboardModule module) {
    if (_items.containsKey(module.id)) throw ArgumentError('Module trùng id');
    _items[module.id] = module;
  }
}
