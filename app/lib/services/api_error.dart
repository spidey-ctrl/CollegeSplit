import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A backend failure translated into a message an end user can act on.
///
/// Carries a short, human-friendly [message] (never a stack trace or raw server
/// JSON) and the originating HTTP [statusCode] when one exists. Because
/// [toString] returns the message, showing it in a UI line is already friendly.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Fallback messages keyed by HTTP status, used when the server didn't send a
/// readable message of its own.
const Map<int, String> _statusFallbacks = {
  400: 'Please check the details you entered and try again.',
  401: 'Your session has expired. Please sign in again.',
  402: 'Payment is required to continue.',
  403: 'You do not have permission to do that.',
  404: 'We could not find what you were looking for.',
  413: 'That upload is too large. Please try again with a smaller file.',
  429: 'Too many requests. Please wait a moment and try again.',
  500: 'Something went wrong on our end. Please try again.',
  501: 'This feature is not supported yet.',
  502: 'The service is having trouble right now. Please try again shortly.',
  503: 'The service is having trouble right now. Please try again shortly.',
  504: 'The service took too long to respond. Please try again.',
};

const String _genericMessage = 'Something went wrong. Please try again.';

/// Builds a user-friendly message from a non-2xx response produced by the
/// backend. Prefers the server's own `message` (string or array), then a
/// status-code fallback, then a safe generic line.
String serverErrorMessage(int statusCode, String body) {
  final serverMessage = _messageFromServerBody(body);
  if (serverMessage != null) return serverMessage;
  return _statusFallbacks[statusCode] ?? _genericMessage;
}

/// Extracts the human-readable `message` the backend sends in an error body.
///
/// NestJS errors are shaped `{"message": "..."}` or `{"message": ["...", ...]}`.
/// Returns null when the body isn't JSON or carries no readable message, so the
/// caller can fall back to a status-code or generic message.
String? _messageFromServerBody(String body) {
  if (body.isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) return message.trim();
      if (message is List && message.isNotEmpty) {
        return message
            .map((m) => m.toString().trim())
            .where((s) => s.isNotEmpty)
            .join('\n');
      }
    }
  } catch (_) {
    // Not JSON (e.g. a proxy error page) — fall through to status fallback.
  }
  return null;
}

/// Converts any error thrown while talking to the backend into a user-friendly
/// string. This is the safe catch-all for UI `catch` blocks: known server
/// errors keep their message, and anything unexpected (network, parse, etc.)
/// collapses to a single friendly line instead of a stack trace.
String friendlyError(Object error) {
  if (error is ApiException) {
    return error.message.trim().isEmpty ? _genericMessage : error.message;
  }
  if (error is SocketException || error is http.ClientException) {
    return 'Could not reach the server. Check your connection and try again.';
  }
  return _genericMessage;
}
