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

/// Real implementation backed by `share_plus` (generic sheet) and `url_launcher`
/// (pre-targeted deep link). Not exercised in widget tests, which inject a fake.
class NativeShareLauncher implements ShareLauncher {
  const NativeShareLauncher();

  @override
  Future<void> launch(SharePayload payload) async {
    final target = payload.target;
    if (target.kind == ShareTargetKind.phone && target.deepLinkUrl != null) {
      final opened = await launchUrl(
        Uri.parse(target.deepLinkUrl!),
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
      // The pre-targeting app isn't installed — fall back to a generic sheet.
    }
    await SharePlus.instance.share(ShareParams(text: payload.text));
  }
}
