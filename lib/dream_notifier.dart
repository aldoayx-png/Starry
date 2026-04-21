import 'package:flutter/material.dart';

/// Notificador global para cambios en sueños
/// Se usa para comunicar entre páginas cuando un sueño ha sido editado/creado/compartido
final dreamChangeNotifier = ValueNotifier<DateTime>(DateTime.now());

/// Dispara una notificación de cambio en sueños
void notifyDreamChange() {
  dreamChangeNotifier.value = DateTime.now();
  debugPrint(
    '📢 Notificación de cambio en sueños: ${dreamChangeNotifier.value}',
  );
}
