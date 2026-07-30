import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

/// Red error banner used on login and register screens.
class AuthErrorBanner extends StatelessWidget {
  final String message;
  const AuthErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.warning)),
          ),
        ],
      ),
    );
  }
}

/// The canonical Waby wave clipper — identical shape to the Home page header.
/// Use this on every screen that needs the branded wave.
class AppWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final h = size.height;
    final w = size.width;
    return Path()
      ..lineTo(0, h - 10)
      ..cubicTo(w * 0.12, h - 10, w * 0.20, h - 22, w * 0.32, h - 18)
      ..cubicTo(w * 0.40, h - 14, w * 0.47, h - 8,  w * 0.54, h - 10)
      ..cubicTo(w * 0.61, h - 12, w * 0.70, h - 26, w * 0.82, h - 22)
      ..cubicTo(w * 0.90, h - 18, w * 0.96, h - 12, w,        h - 12)
      ..lineTo(w, 0)
      ..close();
  }

  @override
  bool shouldReclip(_) => true;
}

/// @deprecated Use [AppWaveClipper] instead.
class AuthWaveClipper extends AppWaveClipper {}

/// Reusable wave header for inner/detail screens (Privacy, Help, etc.).
/// Renders the branded gradient wave with a white back button and page title.
class SharedPageHeader extends StatelessWidget {
  final String title;
  const SharedPageHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipPath(
          clipper: AppWaveClipper(),
          child: Container(
            height: 140,
            width: double.infinity,
            decoration: const BoxDecoration(gradient: kHeaderGradient),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 20, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white,
                      size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
