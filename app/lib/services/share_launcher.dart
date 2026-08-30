import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'expense_service.dart';

/// Chooses how the device's native share sheet is handed off for a Share
/// payload (ticket 10).
///
/// When the backend pre-targets a phone number (a deep link is on file), this
/// opens that deep link so the recipient's app is already aimed at the right
/// chat/number. Otherwise it opens a generic share sheet with the summary text.
///
/// Abstract so tests can record the chosen invocation without a platform plugin.
abstract class ShareLauncher {
  Future<void> launch(SharePayload payload);
}

/// How a Share payload should be handed off to the device.
enum ShareInvocationKind { openDeepLink, openShareSheet }

class ShareInvocation {
  const ShareInvocation(this.kind, {this.deepLinkUrl, this.text});

  final ShareInvocationKind kind;

  /// Non-null when [kind] is [ShareInvocationKind.openDeepLink].
  final String? deepLinkUrl;

  /// The summary text, for the generic sheet (and the deep-link fallback).
  final String? text;
}

/// Decides the native invocation from a Share payload — pre-targeted deep link
/// when a phone is on file, otherwise a generic sheet. Pure and unit-testable,
/// so the "correct share-sheet invocation in each case" (the ticket-10 Seam) is
/// asserted without touching the platform plugins.
ShareInvocation resolveShareInvocation(SharePayload payload) {
  final target = payload.target;
  if (target.kind == ShareTargetKind.phone && target.deepLinkUrl != null) {
    return ShareInvocation(
      ShareInvocationKind.openDeepLink,
      deepLinkUrl: target.deepLinkUrl,
      text: payload.text,
    );
  }
  return ShareInvocation(ShareInvocationKind.openShareSheet, text: payload.text);
}

/// Real implementation backed by `share_plus` (generic sheet) and `url_launcher`
/// (pre-targeted deep link). Not exercised in widget tests, which inject a fake.
class NativeShareLauncher implements ShareLauncher {
  const NativeShareLauncher();

  @override
  Future<void> launch(SharePayload payload) async {
    final invocation = resolveShareInvocation(payload);
    if (invocation.kind == ShareInvocationKind.openDeepLink) {
      final opened = await launchUrl(
        Uri.parse(invocation.deepLinkUrl!),
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
      // The pre-targeting app isn't installed — fall back to a generic sheet.
    }
    await SharePlus.instance.share(ShareParams(text: invocation.text ?? payload.text));
  }
}
