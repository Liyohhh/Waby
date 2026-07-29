import 'package:flutter/material.dart';
import '../core/relations.dart';
import '../core/theme.dart';
import '../widgets/phone_number_field.dart';
import '../widgets/picker_sheet.dart';

/// Slide-up sheet for adding an emergency contact. This does NOT create an
/// app user or family member — it only adds a Telegram-alert recipient
/// (see ContactService.addContact). Family members join the app itself
/// using the separate Family Join Code shown on the Family page.
class InviteFamilySheet extends StatefulWidget {
  const InviteFamilySheet({
    super.key,
    required this.onInvite,
  });

  final Future<void> Function(String name, String phone, String relation) onInvite;

  @override
  State<InviteFamilySheet> createState() => _InviteFamilySheetState();
}

class _InviteFamilySheetState extends State<InviteFamilySheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _relation = kRelationOptions.first;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final relation = _relation;
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in name and phone number')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.onInvite(name, phone, relation);
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
                        'Add Emergency Contact',
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
                  'Add a next-of-kin who will receive Telegram alerts if your '
                  'child is in danger. This does not give them access to the '
                  'app — to add a full family member instead, share the '
                  'Family Join Code from the Family page.',
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
                _fieldLabel('Phone number'),
                const SizedBox(height: 8),
                PhoneNumberField(controller: _phoneCtrl),
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
                              Text('Add Contact'),
                              SizedBox(width: 8),
                              Icon(Icons.check, size: 20),
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
