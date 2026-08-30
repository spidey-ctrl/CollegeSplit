import 'package:flutter_contacts/flutter_contacts.dart';

/// Read access to the device's contact list, abstracted so widget tests can
/// supply a fixture-backed fake without touching platform channels.
abstract class DeviceContacts {
  /// Requests read access to the device contact list. Returns true if granted.
  /// Should be called lazily (when a Participant name is known), never at app
  /// launch. A denial must not block the caller's primary flow.
  Future<bool> requestPermission();

  /// Returns the first phone number whose owner's name matches [name]
  /// (case-insensitive) in the device contact list, or null if none matches.
  /// Assumes [requestPermission] already returned true.
  Future<String?> lookupPhone(String name);
}

/// Production implementation backed by the `flutter_contacts` plugin.
class FlutterDeviceContacts implements DeviceContacts {
  bool _granted = false;

  @override
  Future<bool> requestPermission() async {
    if (_granted) return true;
    try {
      final status =
          await FlutterContacts.permissions.request(PermissionType.read);
      _granted = status == PermissionStatus.granted ||
          status == PermissionStatus.limited;
    } catch (_) {
      _granted = false;
    }
    return _granted;
  }

  @override
  Future<String?> lookupPhone(String name) async {
    final trimmed = name.trim();
    final n = trimmed.toLowerCase();
    if (n.isEmpty) return null;
    try {
      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.name, ContactProperty.phone},
        filter: ContactFilter.name(trimmed),
      );
      for (final c in contacts) {
        if (c.phones.isEmpty) continue;
        final display = (c.displayName ?? '').trim().toLowerCase();
        final first = (c.name?.first ?? '').trim().toLowerCase();
        final full =
            ([c.name?.first, c.name?.last].whereType<String>().join(' '))
                .trim()
                .toLowerCase();
        final matched =
            display.isNotEmpty && (display == n || display.startsWith(n)) ||
                first.isNotEmpty && (first == n || first.startsWith(n)) ||
                full.isNotEmpty && (full == n || full.startsWith(n));
        if (matched) return c.phones.first.number;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
