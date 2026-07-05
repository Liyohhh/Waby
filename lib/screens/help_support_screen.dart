import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../widgets/auth_widgets.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  // ── Design constants (match settings_screen.dart) ─────────────────────────
  static const _kGutter     = 20.0;
  static const _kCardRadius = 12.0;
  static const _kSectionGap = 24.0;
  static const _kIconBg     = Color(0xFFD4EEF8);

  static const _faqs = [
    (
      q: 'What do SAFE, CAUTION, and WARNING mean?',
      a: 'SAFE means everything is normal. CAUTION means something needs your '
          'attention soon — for example, your child isn\'t buckled while you\'re '
          'nearby. WARNING is urgent — your child may be left in the seat while '
          'you\'re away, or the temperature is too high. For warnings, Waby also '
          'alerts your emergency contacts.',
    ),
    (
      q: 'How does Waby know if my child is left behind?',
      a: 'The seat sensor detects your child\'s weight, and the app checks '
          'whether a caregiver is nearby. If weight is detected and no caregiver '
          'is near, Waby raises a warning.',
    ),
    (
      q: 'The device shows "Not connected." What should I do?',
      a: 'Make sure the Waby device is powered on and connected to Wi-Fi, and '
          'that your phone has an internet connection. Then reopen the app.',
    ),
    (
      q: 'How do I add or remove family members?',
      a: 'Go to Settings, then Family Management, or use the Family tab. Family '
          'members you add can receive alerts by email.',
    ),
    (
      q: 'How do I change the alert distance or timing?',
      a: 'Open Settings and adjust the sliders under Distance Setting.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SharedPageHeader(title: 'Help & Support'),
            const SizedBox(height: _kSectionGap),

            // Intro
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kGutter),
              child: const Text(
                'Answers to common questions about using Waby.',
                style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: _kSectionGap),

            // ── FAQ ───────────────────────────────────────────────────────
            _sectionLabel('Frequently Asked Questions'),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kGutter),
              child: _cardContainer(
                child: Theme(
                  // Suppress ExpansionTile's default divider colour
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: Column(
                    children: List.generate(_faqs.length, (i) {
                      final faq = _faqs[i];
                      return Column(
                        children: [
                          ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 2),
                            childrenPadding: const EdgeInsets.fromLTRB(
                                16, 0, 16, 14),
                            expandedCrossAxisAlignment:
                                CrossAxisAlignment.start,
                            title: Text(
                              faq.q,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.navy,
                              ),
                            ),
                            iconColor: AppColors.accent,
                            collapsedIconColor: AppColors.textSecondary,
                            children: [
                              Text(
                                faq.a,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          if (i < _faqs.length - 1)
                            const Divider(
                              height: 1,
                              thickness: 0.5,
                              indent: 16,
                              color: Color(0xFFE5EAF0),
                            ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
            const SizedBox(height: _kSectionGap),

            // ── STILL NEED HELP? ──────────────────────────────────────────
            _sectionLabel('Still Need Help?'),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kGutter),
              child: _cardContainer(
                child: _contactRow(
                  context: context,
                  icon: Icons.support_agent_outlined,
                  label: 'Contact support',
                  subtitle: 'chenuralyaa123@gmail.com',
                  email: 'chenuralyaa123@gmail.com',
                ),
              ),
            ),
            const SizedBox(height: _kSectionGap),

            // ── Version ───────────────────────────────────────────────────
            Center(
              child: const Text(
                'Waby v1.0.0',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

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

  Widget _contactRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required String email,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(_kCardRadius),
      onTap: () => _showEmailDialog(context, email),
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
                          fontSize: 12, color: AppColors.accent)),
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
        title: const Text('Contact Support',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.navy)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Send us an email at:',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
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
                style:
                    TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
