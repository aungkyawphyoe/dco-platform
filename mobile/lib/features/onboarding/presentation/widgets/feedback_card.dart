import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/dco_tokens.dart';
import '../../../../core/widgets/dco_card.dart';
import '../../../../generated/app_localizations.dart';

// A draft is only handed to the user's mail app; AutoX never sends it.
final feedbackEmailLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
final feedbackClipboardProvider = Provider<Future<void> Function(String)>(
  (ref) =>
      (text) => Clipboard.setData(ClipboardData(text: text)),
);

const feedbackSupportEmail = 'support@autoxmm.com';

Uri feedbackEmailUri(String subject, String body) => Uri(
  scheme: 'mailto',
  path: feedbackSupportEmail,
  // mailto needs percent-encoded spaces, not form-encoded plus signs.
  query:
      'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
);

class FeedbackCard extends ConsumerStatefulWidget {
  const FeedbackCard({super.key});

  @override
  ConsumerState<FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends ConsumerState<FeedbackCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _message = TextEditingController();
  bool _includePlatform = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  String get _body => [
    _message.text.trim(),
    if (_includePlatform)
      'Platform: ${kIsWeb ? 'web' : defaultTargetPlatform.name}',
  ].join('\n\n');

  Future<void> _perform({required bool copy}) async {
    if (_busy || _message.text.trim().isEmpty) return;
    final s = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (copy) {
        await ref.read(feedbackClipboardProvider)(
          'To: $feedbackSupportEmail\nSubject: ${s.helpFeedbackSubject}\n\n$_body',
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(s.helpFeedbackCopied)));
        }
      } else {
        final opened = await ref.read(feedbackEmailLauncherProvider)(
          feedbackEmailUri(s.helpFeedbackSubject, _body),
        );
        if (!opened && mounted) {
          setState(() => _error = s.helpFeedbackUnavailable);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = copy
              ? s.helpFeedbackCopyFailed
              : s.helpFeedbackUnavailable,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = AppLocalizations.of(context)!;
    final t = context.tokens;
    final enabled = !_busy && _message.text.trim().isNotEmpty;
    return DcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              s.helpFeedbackTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          SizedBox(height: t.space.s2),
          Text(
            s.helpFeedbackIntro,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: t.text.caption),
          ),
          SizedBox(height: t.space.s2),
          SelectableText(
            feedbackSupportEmail,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          SizedBox(height: t.space.s4),
          TextField(
            key: const Key('feedback-message'),
            controller: _message,
            minLines: 4,
            maxLines: 8,
            maxLength: 2000,
            decoration: InputDecoration(
              labelText: s.helpFeedbackMessage,
              alignLabelWithHint: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(s.helpFeedbackPlatform),
            subtitle: Text(kIsWeb ? 'web' : defaultTargetPlatform.name),
            value: _includePlatform,
            onChanged: _busy
                ? null
                : (value) => setState(() => _includePlatform = value ?? false),
          ),
          if (_error != null)
            Padding(
              padding: EdgeInsets.only(bottom: t.space.s3),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: t.status.dangerFg),
                ),
              ),
            ),
          FilledButton.icon(
            onPressed: enabled ? () => _perform(copy: false) : null,
            icon: const Icon(Icons.mail_outline),
            label: Text(s.helpFeedbackEmail),
          ),
          SizedBox(height: t.space.s2),
          TextButton.icon(
            onPressed: enabled ? () => _perform(copy: true) : null,
            icon: const Icon(Icons.copy_outlined),
            label: Text(s.helpFeedbackCopy),
          ),
        ],
      ),
    );
  }
}
