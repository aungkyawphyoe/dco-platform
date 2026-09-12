import 'package:dco_mobile/core/router/routes.dart';
import 'package:dco_mobile/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dco_mobile/core/theme/dco_tokens.dart';
import 'package:dco_mobile/core/widgets/dco_button.dart';
import 'package:dco_mobile/core/widgets/dco_text_field.dart';
import 'package:dco_mobile/features/family/providers.dart';

class FamilySetupScreen extends ConsumerStatefulWidget {
  final String? joinCode;

  const FamilySetupScreen({super.key, this.joinCode});

  @override
  ConsumerState<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends ConsumerState<FamilySetupScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _shareCode;
  String? _qrData;
  String? _errorText;

  bool get _isJoinMode => widget.joinCode != null;

  @override
  void initState() {
    super.initState();
    if (_isJoinMode) {
      _joinFamily();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _validateName(String value) {
    final s = AppLocalizations.of(context)!;
    if (value.trim().isEmpty) {
      _errorText = s.familyNameRequired;
    } else if (value.trim().length > 100) {
      _errorText = s.familyNameMaxLength;
    } else {
      _errorText = null;
    }
    setState(() {});
  }

  Future<void> _createFamily() async {
    _validateName(_nameController.text);
    if (_errorText != null) return;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(familyRepositoryProvider);
      final family = await repo.createFamily(_nameController.text.trim());

      if (!mounted) return;

      setState(() {
        _shareCode = family.shareCode;
        _qrData = 'dco://family/join?code=${family.shareCode}';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.familyCreatedSuccess,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final message = e.toString();
      if (message.contains('409') || message.contains('already_in_family')) {
        ref.invalidate(myFamilyProvider);
        if (mounted) context.go(AppRoutes.familyManage);
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.familyCreateFailed(e.toString()))));
    }
  }

  Future<void> _joinFamily() async {
    if (widget.joinCode == null) return;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(familyRepositoryProvider);
      await repo.joinFamily(widget.joinCode!);

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.familyJoinedSuccess)),
        );
        context.go(AppRoutes.familyManage);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.familyJoinFailed(e.toString()))));
    }
  }

  void _shareFamily() {
    if (_shareCode == null) return;
    SharePlus.instance.share(
      ShareParams(text: AppLocalizations.of(context)!.familyShareText(_shareCode!)),
    );
  }

  void _navigateToManagement() {
    context.go(AppRoutes.familyManage);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<DcoTokens>()!;
    final showResult = _shareCode != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isJoinMode ? s.familyJoinTitle : s.familyCreateTitle),
        leading: showResult
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _navigateToManagement,
              )
            : null,
      ),
      body: SafeArea(
        child: _isJoinMode && _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: tokens.text.accent),
                    const SizedBox(height: 16),
                    Text(
                      s.familyJoining,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.text.secondary,
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!showResult) ...[
                        Icon(
                          Icons.family_restroom,
                          size: 64,
                          color: tokens.text.accent,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          s.familyCreateHeading,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: tokens.text.primary,
                                fontWeight: FontWeight.w600,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.familyCreateBody,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: tokens.text.secondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        DcoTextField(
                          controller: _nameController,
                          label: s.familyNameLabel,
                          hint: s.familyNameHint,
                          errorText: _errorText,
                          onChanged: _validateName,
                        ),
                        const SizedBox(height: 24),
                        DcoButton(
                          label: _isLoading ? s.familyCreating : s.familyCreateButton,
                          onPressed: _isLoading ? null : _createFamily,
                          loading: _isLoading,
                        ),
                      ] else ...[
                        Icon(
                          Icons.check_circle,
                          size: 64,
                          color: tokens.status.successFg,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          s.familyCreatedHeading,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: tokens.text.primary,
                                fontWeight: FontWeight.w600,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.familyCreatedBody,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: tokens.text.secondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: tokens.background.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: tokens.border.defaultColor,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                s.familyShareCode,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(color: tokens.text.tertiary),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                _shareCode!,
                                style: Theme.of(context).textTheme.displayMedium
                                    ?.copyWith(
                                      color: tokens.text.accent,
                                      fontFamily: 'IBM Plex Mono',
                                      letterSpacing: 4,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              if (_qrData != null)
                                QrImageView(
                                  data: _qrData!,
                                  version: QrVersions.auto,
                                  size: 180,
                                  backgroundColor: Colors.white,
                                ),
                              const SizedBox(height: 16),
                              Text(
                                s.familyShareCodeHelper,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: tokens.text.tertiary),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: DcoButton(
                                      label: s.familyCopyCode,
                                      variant: DcoButtonVariant.secondary,
                                      onPressed: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(s.familyCodeCopied),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DcoButton(
                                      label: s.familyShare,
                                      onPressed: _shareFamily,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          s.familyCodeExpiryHelper,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.text.tertiary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        DcoButton(
                          label: s.familyGoToManagement,
                          onPressed: _navigateToManagement,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
