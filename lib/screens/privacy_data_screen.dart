import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../widgets/auth_widgets.dart';

class PrivacyDataScreen extends StatelessWidget {
  const PrivacyDataScreen({super.key});

  // ── Design constants (match settings_screen.dart) ─────────────────────────
  static const _kGutter     = 20.0;
  static const _kCardRadius = 12.0;
  static const _kSectionGap = 24.0;
  static const _kIconBg     = Color(0xFFD4EEF8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SharedPageHeader(title: 'Privacy & Data'),
            const SizedBox(height: _kSectionGap),

            // Intro
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kGutter),
              child: Text(
                'This is a summary of how Waby handles your information. '
                'Waby is built to keep your child safe, and we only collect '
                'what\'s needed to do that.',
                style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: _kSectionGap),

            // ── WHAT WE COLLECT ───────────────────────────────────────────
            _sectionLabel('What We Collect'),
            const SizedBox(height: 8),
            _card([
              _infoRow(
                icon: Icons.person_outline,
                heading: 'Account details',
                body: 'Your name and email, used to sign you in.',
              ),
              _divider(),
              _infoRow(
                icon: Icons.child_care,
                heading: 'Child profile',
                body: 'Your child\'s name, date of birth, and optional height '
                    'and weight.',
              ),
              _divider(),
              _infoRow(
                icon: Icons.sensors,
                heading: 'Sensor readings',
                body: 'Seat occupancy, temperature, and buckle status from '
                    'the Waby device.',
              ),
              _divider(),
              _infoRow(
                icon: Icons.social_distance_outlined,
                heading: 'Caregiver proximity',
                body: 'Whether a caregiver is near the seat, used to detect '
                    'a left-behind child.',
              ),
              _divider(),
              _infoRow(
                icon: Icons.people_outline,
                heading: 'Emergency contacts',
                body: 'The family members you choose to alert.',
              ),
            ]),
            const SizedBox(height: _kSectionGap),

            // ── HOW WE USE IT ─────────────────────────────────────────────
            _sectionLabel('How We Use It'),
            const SizedBox(height: 8),
            _card([
              _infoRow(
                icon: Icons.security_outlined,
                heading: 'Safety alerts only',
                body: 'Waby uses this information to detect unsafe conditions '
                    'and to send alerts to you and your chosen emergency '
                    'contacts. It is not sold or shared for advertising.',
              ),
            ]),
            const SizedBox(height: _kSectionGap),

            // ── WHERE IT'S STORED ─────────────────────────────────────────
            _sectionLabel('Where It\'s Stored'),
            const SizedBox(height: 8),
            _card([
              _infoRow(
                icon: Icons.cloud_outlined,
                heading: 'Secure cloud storage',
                body: 'Your data is stored securely in the cloud and sent '
                    'from the Waby device over your Wi-Fi network. Alerts '
                    'to emergency contacts are delivered by email.',
              ),
            ]),
            const SizedBox(height: _kSectionGap),

            // ── YOUR CHOICES ──────────────────────────────────────────────
            _sectionLabel('Your Choices'),
            const SizedBox(height: 8),
            _card([
              _infoRow(
                icon: Icons.tune_outlined,
                heading: 'You\'re in control',
                body: 'You control your emergency contacts in Family '
                    'Management, and you can turn specific alerts on or off '
                    'in Settings. To request a copy of your data or have it '
                    'deleted, contact us below.',
              ),
            ]),
            const SizedBox(height: _kSectionGap),

            // ── CONTACT ───────────────────────────────────────────────────
            _sectionLabel('Contact'),
            const SizedBox(height: 8),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: _kGutter),
              child: _cardContainer(
                child: _contactRow(
                  context: context,
                  icon: Icons.mail_outline,
                  label: 'Email us',
                  subtitle: 'chenuralyaa123@gmail.com',
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Shared card helpers ───────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: _kGutter),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
      );

  Widget _card(List<Widget> children) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: _kGutter),
        child: _cardContainer(child: Column(children: children)),
      );

  Widget _cardContainer({required Widget child}) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_kCardRadius),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );

  Widget _divider() => const Divider(
        height: 1,
        thickness: 0.5,
        indent: 20,
        color: Color(0xFFE5EAF0),
      );

  Widget _infoRow({
    required IconData icon,
    required String heading,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: _kIconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(heading,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy)),
                const SizedBox(height: 4),
                Text(body,
                    style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(_kCardRadius),
      onTap: () => _showEmailDialog(context, subtitle),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: _kIconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.accent, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.accent)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 22),
          ],
        ),
      ),
    );
  }

  void _showEmailDialog(BuildContext context, String email) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Contact Us',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.navy)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Send us an email at:',
                style:
                    TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: email));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Email address copied'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Copy Address',
                style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
