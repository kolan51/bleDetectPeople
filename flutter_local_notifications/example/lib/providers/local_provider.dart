// ignore_for_file: only_throw_errors
import 'package:flutter/Material.dart';

// Provider class for managing the connection to the firebase database
class LocalProvider extends ChangeNotifier {
  bool? _isFirstLoaded = false;

  set isLoaded(bool? isLoaded) {
    _isFirstLoaded = isLoaded;
  }

  bool? get isLoaded => _isFirstLoaded;
}
