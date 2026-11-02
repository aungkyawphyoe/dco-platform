import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/dco_tokens.dart';
import '../../../../generated/app_localizations.dart';
import '../../domain/share_invite_link.dart';

/// Camera view that reads a vehicle share QR and pops the 8-character code.
///
/// The QR carries `dco://vehicle/share/join?code=…`; a bare code is accepted
/// too so codes printed or pasted elsewhere keep working. Popping without a
/// value means the user backed out or chose to type the code instead.
class ScanShareQrScreen extends StatefulWidget {
  const ScanShareQrScreen({super.key});

  @override
  State<ScanShareQrScreen> createState() => _ScanShareQrScreenState();
}

class _ScanShareQrScreenState extends State<ScanShareQrScreen> {
  late final MobileScannerController _controller;
  bool _handedOff = false;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handedOff || !mounted) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final invite = ShareInviteLink.tryParse(raw);
      if (invite == null) {
        if (!_invalid) setState(() => _invalid = true);
        continue;
      }
      _handedOff = true;
      Navigator.of(context).pop(invite.code);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(s.shareScanTitle),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraUnavailable(
              message:
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                  ? s.shareScanPermission
                  : s.shareScanCameraError,
            ),
          ),
          const IgnorePointer(child: _ScanFrame()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                tokens.space.s5,
                tokens.space.s6,
                tokens.space.s5,
                tokens.space.s4,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.shareScanHint,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                    if (_invalid) ...[
                      SizedBox(height: tokens.space.s3),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: tokens.space.s3,
                          vertical: tokens.space.s2,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.status.dangerBg,
                          borderRadius: BorderRadius.circular(tokens.radius.md),
                        ),
                        child: Text(
                          s.shareScanInvalid,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.status.dangerFg),
                        ),
                      ),
                    ],
                    SizedBox(height: tokens.space.s2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ValueListenableBuilder<MobileScannerState>(
                          valueListenable: _controller,
                          builder: (context, state, _) {
                            if (!state.isRunning ||
                                state.torchState == TorchState.unavailable) {
                              return const SizedBox.shrink();
                            }
                            final on = state.torchState == TorchState.on;
                            return IconButton(
                              tooltip: s.shareScanTorch,
                              onPressed: () =>
                                  unawaited(_controller.toggleTorch()),
                              icon: Icon(
                                on ? Icons.flashlight_on : Icons.flashlight_off,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                        SizedBox(width: tokens.space.s2),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            s.shareScanEnterManually,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dim corner brackets marking where to hold the QR code.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth < 360 ? 220.0 : 260.0;
        return Center(
          child: Container(
            width: side,
            height: side,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 3,
              ),
              borderRadius: BorderRadius.circular(tokens.radius.lg),
            ),
          ),
        );
      },
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final s = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.space.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              size: 48,
              color: Colors.white70,
            ),
            SizedBox(height: tokens.space.s4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
            SizedBox(height: tokens.space.s4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                s.shareScanEnterManually,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
