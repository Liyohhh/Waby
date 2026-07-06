import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/relations.dart';
import '../core/theme.dart';
import '../widgets/picker_sheet.dart';

/// Slide-up sheet for inviting a family member (Figma: Invite Family Member).
class InviteFamilySheet extends StatefulWidget {
  const InviteFamilySheet({
    super.key,
    required this.onInvite,
    this.joinCode = 'BT - 8942',
  });

  final Future<void> Function(String name, String email, String phone, String relation) onInvite;
  final String joinCode;

  @override
  State<InviteFamilySheet> createState() => _InviteFamilySheetState();
}

class _InviteFamilySheetState extends State<InviteFamilySheet> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _relation = kRelationOptions.first;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final relation = _relation;
    if (name.isEmpty || email.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in name, email and phone number')),
      );
      return;
    }
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.onInvite(name, email, phone, relation);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Invite Family Member',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF031E2A),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Color(0xFF031E2A)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Add a next-of-kin who will receive alerts if your child is in danger.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0x8C031E2A),
                  ),
                ),
                const SizedBox(height: 24),
                _fieldLabel('Full name'),
                const SizedBox(height: 8),
                _field(_nameCtrl, hint: 'e.g. Ahmad bin Ali'),
                const SizedBox(height: 16),
                _fieldLabel('Email'),
                const SizedBox(height: 8),
                _field(_emailCtrl,
                    hint: 'e.g. dad@email.com',
                    keyboard: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _fieldLabel('Phone number'),
                const SizedBox(height: 8),
                _field(_phoneCtrl,
                    hint: 'e.g. +60 12 345 6789',
                    keyboard: TextInputType.phone),
                const SizedBox(height: 16),
                _fieldLabel('Relation'),
                const SizedBox(height: 8),
                _selectField(
                  value: _relation,
                  onTap: () => showPickerSheet(
                    context,
                    title: 'Relation',
                    options: kRelationOptions,
                    current: _relation,
                    onSelected: (v) => setState(() => _relation = v),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Send Invite'),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.black.withAlpha(30))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or share code',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0x8C031E2A),
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.black.withAlpha(30))),
                  ],
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: widget.joinCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Join code copied')),
                    );
                  },
                  child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F5FE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF1F61B2).withAlpha(80),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFBDD6F3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.bolt,
                            color: Color(0xFF1F61B2), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Family Join Code',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF031E2A),
                              ),
                            ),
                            Text(
                              widget.joinCode,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF3D7FB0),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.copy, color: Color(0xFF3D7FB0), size: 20),
                    ],
                  ),
                ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF031E2A),
      ),
    );
  }

  Widget _field(
    TextEditingController controller, {
    required String hint,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.field,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _selectField({
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF031E2A),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0x8C031E2A), size: 20),
          ],
        ),
      ),
    );
  }
}
