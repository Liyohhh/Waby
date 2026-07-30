import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/car.dart';
import '../services/car_service.dart';
import '../services/family_service.dart';
import '../widgets/auth_widgets.dart';

class CarSettingsScreen extends StatefulWidget {
  const CarSettingsScreen({super.key});

  @override
  State<CarSettingsScreen> createState() => _CarSettingsScreenState();
}

class _CarSettingsScreenState extends State<CarSettingsScreen> {
  final CarService _carService = CarService();
  final FamilyService _familyService = FamilyService();
  late final Stream<List<Car>> _carsStream = _carService.carsStream();
  String? _activeCarId;

  @override
  void initState() {
    super.initState();
    _loadActiveCarId();
  }

  Future<void> _loadActiveCarId() async {
    final id = await _familyService.getActiveCarId();
    if (mounted) setState(() => _activeCarId = id);
  }

  Future<void> _setActive(Car car) async {
    setState(() => _activeCarId = car.id);
    try {
      await _familyService.setActiveCar(car.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not set current car.')),
        );
        _loadActiveCarId();
      }
    }
  }

  Future<void> _deleteCar(Car car) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete car?',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
        content: Text('Remove "${car.name}" from your saved cars?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.warning)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _carService.deleteCar(car.id);
      if (_activeCarId == car.id && mounted) {
        setState(() => _activeCarId = null);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete car.')),
        );
      }
    }
  }

  Future<void> _showCarSheet({Car? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _CarFormSheet(existing: existing, onSaved: () {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SharedPageHeader(title: 'Car Profiles'),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Save the cars your Waby seat is used in. We'll ask which "
                "one you're using so alerts can mention it.",
                style: const TextStyle(
                    fontSize: 13, height: 1.4, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Car>>(
                stream: _carsStream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: AppColors.accent));
                  }
                  final cars = snap.data ?? [];
                  if (cars.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Center(
                        child: Text(
                          'No cars saved yet. Add your first car below.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: cars.length,
                    itemBuilder: (_, i) {
                      final car = cars[i];
                      final isActive = car.id == _activeCarId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: isActive
                                ? Border.all(color: AppColors.accent, width: 1.5)
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: carColorFromHex(car.color),
                              radius: 16,
                            ),
                            title: Text(car.name,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: (isActive ||
                                    (car.plateNumber?.isNotEmpty ?? false))
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isActive)
                                        const Text('Currently in use',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.accent,
                                                fontWeight: FontWeight.w600)),
                                      if (car.plateNumber != null &&
                                          car.plateNumber!.isNotEmpty)
                                        Text(car.plateNumber!,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppColors.textSecondary)),
                                    ],
                                  )
                                : null,
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'use') _setActive(car);
                                if (v == 'edit') _showCarSheet(existing: car);
                                if (v == 'delete') _deleteCar(car);
                              },
                              itemBuilder: (_) => [
                                if (!isActive)
                                  const PopupMenuItem(
                                      value: 'use', child: Text('Set as current car')),
                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                const PopupMenuItem(
                                    value: 'delete', child: Text('Delete')),
                              ],
                            ),
                            onTap: () => _showCarSheet(existing: car),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCarSheet(),
        backgroundColor: AppColors.navy,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Car', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// ── Add / Edit car sheet ────────────────────────────────────────────────

class _CarFormSheet extends StatefulWidget {
  const _CarFormSheet({this.existing, required this.onSaved});

  final Car? existing;
  final VoidCallback onSaved;

  @override
  State<_CarFormSheet> createState() => _CarFormSheetState();
}

class _CarFormSheetState extends State<_CarFormSheet> {
  final _nameCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  late String _color;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.existing?.name ?? '';
    _plateCtrl.text = widget.existing?.plateNumber ?? '';
    _color = widget.existing?.color ?? kCarColorOptions.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final plate = _plateCtrl.text.trim().toUpperCase();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a car name')),
      );
      return;
    }
    if (plate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a number plate')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.existing != null) {
        await CarService().updateCar(
          id: widget.existing!.id,
          name: name,
          color: _color,
          plateNumber: plate,
        );
      } else {
        await CarService().addCar(
          name: name,
          color: _color,
          plateNumber: plate,
        );
      }
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save car. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration:
                    BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.existing != null ? 'Edit Car' : 'Add Car',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF031E2A)),
            ),
            const SizedBox(height: 20),
            const Text('Car name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. Honda City',
                filled: true,
                fillColor: AppColors.field,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Number plate',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _plateCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'e.g. ABC 1234',
                filled: true,
                fillColor: AppColors.field,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Color', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: kCarColorOptions.map((hex) {
                final selected = hex == _color;
                return GestureDetector(
                  onTap: () => setState(() => _color = hex),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: carColorFromHex(hex),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? AppColors.navy : Colors.black12,
                        width: selected ? 3 : 1,
                      ),
                    ),
                    child: selected
                        ? Icon(Icons.check,
                            size: 18,
                            color: hex == '#FFFFFF' ? Colors.black : Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.existing != null ? 'Save Changes' : 'Add Car'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
