import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';
import '../core/theme.dart';

/// Combined country-code + local-number input. `controller.text` always
/// holds the FULL stored value (e.g. "+60123456789") so callers can keep
/// reading/writing it exactly as before — only the input UI changes.
class PhoneNumberField extends StatefulWidget {
  const PhoneNumberField({
    super.key,
    required this.controller,
    this.validator,
    this.hint = '12 345 6789',
  });

  final TextEditingController controller;
  final String? Function(String?)? validator;
  final String hint;

  @override
  State<PhoneNumberField> createState() => _PhoneNumberFieldState();
}

class _PhoneNumberFieldState extends State<PhoneNumberField> {
  late CountryDialCode _selected;
  late final TextEditingController _localCtrl;

  @override
  void initState() {
    super.initState();
    final parsed = _splitStored(widget.controller.text);
    _selected = parsed.$1;
    _localCtrl = TextEditingController(text: parsed.$2);
    _localCtrl.addListener(_syncCombined);
  }

  @override
  void didUpdateWidget(covariant PhoneNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-sync if the controller's text was set externally (e.g. after an
    // async profile load finishes AFTER this widget already built once).
    if (oldWidget.controller != widget.controller) return;
    final combined = '${_selected.dialCode}${_localCtrl.text.trim()}';
    if (widget.controller.text != combined &&
        widget.controller.text.isNotEmpty) {
      final parsed = _splitStored(widget.controller.text);
      _selected = parsed.$1;
      _localCtrl.text = parsed.$2;
    }
  }

  @override
  void dispose() {
    _localCtrl.removeListener(_syncCombined);
    _localCtrl.dispose();
    super.dispose();
  }

  static (CountryDialCode, String) _splitStored(String stored) {
    final trimmed = stored.trim();
    if (trimmed.startsWith('+')) {
      final sorted = [...kCountryDialCodes]
        ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
      for (final c in sorted) {
        if (trimmed.startsWith(c.dialCode)) {
          return (c, trimmed.substring(c.dialCode.length).trim());
        }
      }
    }
    final fallback =
        kCountryDialCodes.firstWhere((c) => c.dialCode == kDefaultDialCode);
    return (fallback, trimmed);
  }

  void _syncCombined() {
    widget.controller.text = '${_selected.dialCode}${_localCtrl.text.trim()}';
  }

  Future<void> _pickCountry() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DialCodeSheet(
        current: _selected,
        onSelected: (c) {
          setState(() => _selected = c);
          _syncCombined();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _pickCountry,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.public,
                    size: 18, color: AppColors.navy),
                const SizedBox(width: 6),
                Text(_selected.dialCode,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down,
                    size: 18, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: _localCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: widget.validator,
            decoration: InputDecoration(
              hintText: widget.hint,
              filled: true,
              fillColor: AppColors.field,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DialCodeSheet extends StatelessWidget {
  const _DialCodeSheet({required this.current, required this.onSelected});
  final CountryDialCode current;
  final ValueChanged<CountryDialCode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Country code',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy)),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: kCountryDialCodes.length,
              itemBuilder: (_, i) {
                final c = kCountryDialCodes[i];
                final selected =
                    c.dialCode == current.dialCode && c.name == current.name;
                return ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD4EEF8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.public,
                        size: 18, color: AppColors.accent),
                  ),
                  title: Text('${c.name} (${c.dialCode})'),
                  trailing: selected
                      ? const Icon(Icons.check_circle,
                          color: AppColors.accent, size: 20)
                      : null,
                  onTap: () {
                    onSelected(c);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
