import 'package:dco_mobile/core/router/routes.dart';
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
    if (value.trim().isEmpty) {
      _errorText = 'Family name is required';
    } else if (value.trim().length > 100) {
      _errorText = 'Name must be 100 characters or less';
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
          const SnackBar(
            content: Text(
              'Family created! Share the code with family members.',
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
      ).showSnackBar(SnackBar(content: Text('Failed to create family: $e')));
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
          const SnackBar(content: Text('Joined family successfully!')),
        );
        context.go(AppRoutes.familyManage);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to join family: $e')));
    }
  }

  void _shareFamily() {
    if (_shareCode == null) return;
    SharePlus.instance.share(
      ShareParams(text: 'Join my DCO family! Code: $_shareCode'),
    );
  }

  void _navigateToManagement() {
    context.go(AppRoutes.familyManage);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<DcoTokens>()!;
    final showResult = _shareCode != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isJoinMode ? 'Join Family' : 'Create Family'),
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
                      'Joining family...',
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
                          'Create Your Family',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: tokens.text.primary,
                                fontWeight: FontWeight.w600,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Invite members to share vehicles and manage access together.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: tokens.text.secondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        DcoTextField(
                          controller: _nameController,
                          label: 'Family Name',
                          hint: 'e.g., Smith Family',
                          errorText: _errorText,
                          onChanged: _validateName,
                        ),
                        const SizedBox(height: 24),
                        DcoButton(
                          label: _isLoading ? 'Creating...' : 'Create Family',
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
                          'Family Created!',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: tokens.text.primary,
                                fontWeight: FontWeight.w600,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Share this code with family members so they can join.',
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
                                'Share Code',
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
                                'Scan with DCO app to join',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: tokens.text.tertiary),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: DcoButton(
                                      label: 'Copy Code',
                                      variant: DcoButtonVariant.secondary,
                                      onPressed: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Code copied!'),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DcoButton(
                                      label: 'Share',
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
                          'Code expires in 7 days. Regenerating invalidates the old code.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.text.tertiary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        DcoButton(
                          label: 'Go to Family Management',
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
