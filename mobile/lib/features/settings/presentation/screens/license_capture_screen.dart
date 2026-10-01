import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/dco_tokens.dart';
import '../../../../generated/app_localizations.dart';

class LicenseCaptureScreen extends ConsumerStatefulWidget {
  const LicenseCaptureScreen({super.key, this.side = 'front'});

  final String side;

  @override
  ConsumerState<LicenseCaptureScreen> createState() =>
      _LicenseCaptureScreenState();
}

class _LicenseCaptureScreenState extends ConsumerState<LicenseCaptureScreen> {
  bool _processing = false;

  Future<void> _pickAndCrop(ImageSource source) async {
    setState(() => _processing = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      if (picked == null) {
        setState(() => _processing = false);
        return;
      }

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 3, ratioY: 2),
        uiSettings: [
          AndroidUiSettings(
            initAspectRatio: CropAspectRatioPreset.ratio3x2,
            lockAspectRatio: true,
            cropStyle: CropStyle.rectangle,
            hideBottomControls: true,
            toolbarTitle: '',
            toolbarColor: Colors.black87,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: Colors.white,
            backgroundColor: Colors.black87,
          ),
          IOSUiSettings(
            aspectRatioLockEnabled: true,
            cropStyle: CropStyle.rectangle,
            aspectRatioPresets: const [
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          WebUiSettings(
            context: context,
            initialAspectRatio: 3.0 / 2.0,
            presentStyle: WebPresentStyle.dialog,
          ),
        ],
      );

      if (croppedFile != null && mounted) {
        GoRouter.of(context).pop(croppedFile.path);
      } else {
        setState(() => _processing = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.userDetailUploadFailed(e.toString()),
          ),
        ),
      );
      setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final isFront = widget.side == 'front';

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Text(
          isFront
              ? s.profileLicenseFrontPhotoTitle
              : s.profileLicenseBackPhotoTitle,
        ),
        actions: [
          if (_processing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: tokens.text.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          _buildGridGuide(context, tokens, s, isFront),
          if (_processing) _buildProcessingOverlay(context, tokens, s),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _processing
                      ? null
                      : () => _pickAndCrop(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, size: 20),
                  label: Text(s.userDetailTakePhoto),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.background.card,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.radius.md),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _processing
                      ? null
                      : () => _pickAndCrop(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, size: 20),
                  label: Text(s.userDetailChooseGallery),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.background.card,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.radius.md),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridGuide(
    BuildContext context,
    DcoTokens tokens,
    AppLocalizations s,
    bool isFront,
  ) {
    return Center(
      child: AspectRatio(
        aspectRatio: 3 / 2,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 240),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.radius.md),
            border: Border.all(color: Colors.white60, width: 2),
          ),
          child: CustomPaint(
            painter: _GridPainter(),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isFront ? Icons.credit_card : Icons.credit_card,
                      color: Colors.white54,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isFront
                          ? s.profileLicensePlaceFront
                          : s.profileLicensePlaceBack,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay(
    BuildContext context,
    DcoTokens tokens,
    AppLocalizations s,
  ) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        color: Colors.black45,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: tokens.text.accent),
              const SizedBox(height: 16),
              Text(
                s.profileLicenseProcessing,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white30
      ..strokeWidth = 1;

    final dx1 = size.width / 3;
    final dx2 = size.width / 3 * 2;
    canvas.drawLine(Offset(dx1, 0), Offset(dx1, size.height), paint);
    canvas.drawLine(Offset(dx2, 0), Offset(dx2, size.height), paint);

    final dy1 = size.height / 3;
    final dy2 = size.height / 3 * 2;
    canvas.drawLine(Offset(0, dy1), Offset(size.width, dy1), paint);
    canvas.drawLine(Offset(0, dy2), Offset(size.width, dy2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
