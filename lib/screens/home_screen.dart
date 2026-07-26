import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../core/app_state.dart';
import '../core/demo_data.dart';
import '../core/theme.dart';
import '../models/child.dart';
import '../models/seat_status.dart';
import '../services/auth_service.dart';
import '../services/child_service.dart';
import '../services/device_service.dart';
import '../services/family_service.dart';
import '../services/image_upload_service.dart';
import '../services/live_service.dart';
import '../widgets/signed_avatar.dart';
import '../widgets/status_pill.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

/// Waby home dashboard, wired to live Supabase data from the `live` table.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LiveService _liveService = LiveService();
  final AuthService _auth = AuthService();
  late final Stream<SeatStatus> _liveStream = _liveService.liveStream();

  final ChildService _childService = ChildService();
  late final Stream<List<Child>> _childrenStream =
      _childService.myChildrenStream();

  final String _greetingName = AppState.greetingName.value ?? 'there';
  bool _demoFamily = false;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadDemoFamily();
  }

  Future<void> _loadDemoFamily() async {
    final v = await FamilyService().isDemoFamily();
    if (mounted) setState(() => _demoFamily = v);
  }

  Future<void> _loadUserName() async {
    if (AppState.greetingName.value == null) {
      final name = await _auth.getGreetingName();
      AppState.greetingName.value = name;
    }
    if (AppState.avatarPath.value == null) {
      final profile = await _auth.getProfile();
      AppState.avatarPath.value = profile?['avatar_path'] as String?;
    }
  }

  Future<void> _refreshProfileHeader() async {
    final profile = await _auth.getProfile();
    if (!mounted) return;
    AppState.avatarPath.value = profile?['avatar_path'] as String?;
    AppState.greetingName.value = await _auth.getGreetingName();
  }

  _CardStatus _mapSeverity(SeatSeverity s) => switch (s) {
        SeatSeverity.safe => _CardStatus.safe,
        SeatSeverity.caution => _CardStatus.caution,
        SeatSeverity.warning => _CardStatus.warning,
      };

  String _formatDob(DateTime? d) {
    if (d == null) return '';
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return 'DOB: ${d.day} ${m[d.month - 1]} ${d.year}';
  }

  String _formatDetails(double? w, double? h) {
    final parts = <String>[];
    if (w != null) parts.add('${w.toStringAsFixed(1)} kg');
    if (h != null) parts.add('${h.toStringAsFixed(0)} cm');
    return parts.join(' · ');
  }

  Widget _emptyState() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
        child: Column(
          children: [
            Icon(Icons.event_seat, size: 72, color: AppColors.accent.withAlpha(120)),
            const SizedBox(height: 16),
            const Text('No device yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('Add your Waby seat to start monitoring your baby.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<List<Child>>(
        stream: _childrenStream,
        builder: (context, childSnap) {
          final children = childSnap.data ?? const <Child>[];
          return StreamBuilder<SeatStatus>(
            stream: _liveStream,
            builder: (context, liveSnap) {
              final rawLive = liveSnap.data ?? SeatStatus.empty();
              final useDemo = DemoAccount.useDemoDisplay(
                isDemoUser: _auth.isDemoUser,
                isDemoFamily: _demoFamily,
              );
              final headerStatus = useDemo
                  ? (rawLive.temperature > 0 ? rawLive : DemoAccount.headerLive)
                  : rawLive;
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<String?>(
                      valueListenable: AppState.greetingName,
                      builder: (context, name, _) {
                        return _header(
                            context, headerStatus, name ?? _greetingName);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Your Children',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (childSnap.connectionState == ConnectionState.waiting &&
                        !childSnap.hasData)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accent,
                          ),
                        ),
                      )
                    else if (childSnap.hasData && children.isEmpty)
                      _emptyState()
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            for (final c in children) ...[
                              Builder(builder: (_) {
                                final seed = useDemo
                                    ? DemoAccount.childSeedFor(c.name)
                                    : null;
                                return _ChildCard(
                                  name: c.name,
                                  dob: _formatDob(c.dob),
                                  details:
                                      _formatDetails(c.weightKg, c.heightCm),
                                  status: _mapSeverity(
                                      seed?.status ?? rawLive.severity),
                                  present: seed?.present ?? rawLive.present,
                                  buckled: seed?.buckled ?? rawLive.buckled,
                                  near: seed?.near ?? rawLive.distanceNear,
                                  battery: seed?.battery ?? rawLive.battery,
                                  photoPath: c.photoPath,
                                );
                              }),
                              const SizedBox(height: 16),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: Builder(
                          builder: (ctx) => ElevatedButton(
                            onPressed: () => _showAddDeviceSheet(ctx),
                            child: const Text('Add Device'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 110),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await AuthService().signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (r) => false,
              );
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, SeatStatus status, String firstName) {
    // Outer Stack: bg → wave → car (on top of wave) → text
    return Stack(
      children: [
        // ── 1. Light blue background ────────────────────────────────────────
        Positioned.fill(child: Container(color: const Color(0xFFE5FCFF).withAlpha(180))),

        // ── 2. Wave gradient (behind the car) ───────────────────────────────
              ClipPath(
                clipper: _WaveClipper(),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: const BoxDecoration(gradient: kHeaderGradient),
                ),
              ),

        // ── 3. Car image — ON TOP of wave, beside temperature content ────────
        //    left+right pins the car to the right half; Center handles
        //    horizontal centering regardless of image aspect ratio.
        Positioned(
          left: 210,
          right: -15,
          top: 95,
          bottom: 0,
          child: Center(
              child: RotatedBox(
              quarterTurns: 1, // +90° → front of car faces up
              child: Image.asset(
                'assets/images/car_pic_on_top.png',
                height: 85, // controls visual width after rotation
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => const SizedBox(),
              ),
            ),
          ),
        ),

        // ── 4. Profile row (always on top) ──────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                    _refreshProfileHeader();
                  },
                  child: ValueListenableBuilder<String?>(
                    valueListenable: AppState.avatarPath,
                    builder: (context, path, _) => SignedAvatar(
                      photoPath: path,
                      radius: 22,
                      backgroundColor: Colors.white,
                      fallbackIcon: Icons.person,
                      iconColor: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hi, $firstName!',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                      const Text('Welcome back!',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _confirmSignOut(context),
                  child: const Icon(Icons.logout, color: Colors.white, size: 26),
                ),
              ],
            ),
          ),
        ),

        // ── 5. Temperature section (below the wave, left side only) ─────────
        Padding(
          padding: const EdgeInsets.only(top: 140),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Left half only — the car occupies the right portion
                final leftWidth = constraints.maxWidth * 0.55;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.thermostat,
                            color: Color(0xFF0063BA), size: 64),
                        const SizedBox(width: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('${status.temperature.toStringAsFixed(0)}°C',
                                style: const TextStyle(
                                    color: Color(0xFF0063BA),
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800)),
                            Text("$firstName's car",
                                style: const TextStyle(
                                    color: Color(0xFF031E2A), fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: leftWidth,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ((status.temperature - 20) / (32 - 20))
                              .clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: Colors.black12,
                          color: const Color(0xFF088BEA),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: leftWidth,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('20°C',
                              style: TextStyle(
                                  color: Color(0xFF031E2A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          Text('32°C',
                              style: TextStyle(
                                  color: Color(0xFF031E2A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ── Card status enum ──────────────────────────────────────────────────────────

enum _CardStatus { safe, caution, warning }

// ── Add Device sheet ──────────────────────────────────────────────────────────

Future<void> _showAddDeviceSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: const _AddDeviceSheet(),
    ),
  );
}

class _AddDeviceSheet extends StatefulWidget {
  const _AddDeviceSheet();

  @override
  State<_AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends State<_AddDeviceSheet> {
  int _step = 0;
  bool _connecting = false;
  bool _saving = false;
  String? _error;

  final _name = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  final _dobController = TextEditingController();
  final _childFormKey = GlobalKey<FormState>();
  DateTime? _dob;

  String? _childId;
  String? _photoPath;
  File? _photoPreview;
  bool _uploadingPhoto = false;

  Future<void> _pickChildPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final familyId = await FamilyService().myFamilyId();
    if (familyId == null || !mounted) return;

    _childId ??= const Uuid().v4();
    setState(() => _uploadingPhoto = true);

    final result = await ImageUploadService().pickCropAndUpload(
      source: source,
      familyId: familyId,
      entityType: 'children',
      entityId: _childId!,
    );

    if (result != null) {
      SignedAvatar.invalidate(result.path);
    }

    if (!mounted) return;
    setState(() {
      _uploadingPhoto = false;
      if (result != null) {
        _photoPath = result.path;
        _photoPreview = result.localFile;
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    _height.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() { _connecting = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() { _connecting = false; _step = 1; });
  }

  DateTime? _parseDob(String input) {
    final parts = input.split('/');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    if (parts[2].length != 4) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final dt = DateTime(y, m, d);
    if (dt.day != d || dt.month != m || dt.year != y) return null;
    return dt;
  }

  DateTime _dobMinDate() {
    final now = DateTime.now();
    return DateTime(now.year - 12, now.month, 1);
  }

  DateTime _dobMaxDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month - 1, now.day);
  }

  bool _isDobInRange(DateTime dt) {
    final min = _dobMinDate();
    final max = _dobMaxDate();
    return !dt.isBefore(min) && !dt.isAfter(max);
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDate: (_dob != null && _isDobInRange(_dob!)) ? _dob! : _dobMaxDate(),
      firstDate: _dobMinDate(),
      lastDate: _dobMaxDate(),
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _save() async {
    if (!_childFormKey.currentState!.validate()) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = "Please enter the child's name.");
      return;
    }
    final parsed = _parseDob(_dobController.text);
    if (parsed == null) {
      setState(() => _error = 'Invalid date (use DD/MM/YYYY)');
      return;
    }
    if (!_isDobInRange(parsed)) {
      setState(() => _error = 'Child must be between 1 month and 12 years old');
      return;
    }
    _dob = parsed;
    setState(() { _saving = true; _error = null; });
    try {
      await DeviceService().addDeviceWithChild(
        deviceName: 'Waby Seat',
        childName: _name.text.trim(),
        dob: _dob,
        weightKg: double.tryParse(_weight.text),
        heightCm: double.tryParse(_height.text),
        childId: _childId,
        photoPath: _photoPath,
        devicePhotoPath: _photoPath,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not add device. Please try again.';
      });
    }
  }

  Widget _saveButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _saving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _saving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Save',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 1) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                    const SizedBox(height: 20),
                    const Text(
                      'Add your child',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _childFormKey,
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Photo (optional)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: GestureDetector(
                          onTap: _uploadingPhoto ? null : _pickChildPhoto,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: AppColors.field,
                                backgroundImage: _photoPreview != null
                                    ? FileImage(_photoPreview!)
                                    : null,
                                child: _uploadingPhoto
                                    ? const CircularProgressIndicator(
                                        strokeWidth: 2)
                                    : (_photoPreview == null
                                        ? const Icon(Icons.child_care,
                                            size: 36,
                                            color: AppColors.textSecondary)
                                        : null),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.navy,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Child name',
                          filled: true,
                          fillColor: AppColors.field,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dobController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [_DateInputFormatter()],
                        decoration: InputDecoration(
                          labelText: 'Date of Birth',
                          hintText: 'DD/MM/YYYY',
                          filled: true,
                          fillColor: AppColors.field,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.calendar_today,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: _saving ? null : _pickDob,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a date of birth';
                          }
                          final parsed = _parseDob(value);
                          if (parsed == null) {
                            return 'Invalid date (use DD/MM/YYYY)';
                          }
                          if (!_isDobInRange(parsed)) {
                            return 'Child must be between 1 month and 12 years old';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          final parsed = _parseDob(value);
                          _dob = (parsed != null && _isDobInRange(parsed))
                              ? parsed
                              : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _weight,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Weight (kg)',
                          filled: true,
                          fillColor: AppColors.field,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final val = double.tryParse(v);
                          if (val == null) return 'Enter a valid number';
                          if (val <= 0 || val > 60) {
                            return 'Enter a weight up to 60 kg';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _height,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Height (cm)',
                          filled: true,
                          fillColor: AppColors.field,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final val = double.tryParse(v);
                          if (val == null) return 'Enter a valid number';
                          if (val <= 0 || val > 200) {
                            return 'Enter a height up to 200 cm';
                          }
                          return null;
                        },
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ],
                  ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _saveButton(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            // Drag handle
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
            const SizedBox(height: 20),

            const Text(
              'Add Device',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap Connect to link your Waby seat.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: _connecting
                  ? const SizedBox(
                      height: 64,
                      width: 64,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.accent,
                      ),
                    )
                  : const Icon(
                      Icons.wifi_tethering,
                      size: 64,
                      color: AppColors.accent,
                    ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _connecting ? null : _connect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Connect',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.warning,
                ),
              ),
            ],
          ],
        ),
    );
  }
}

// ── Child status card ─────────────────────────────────────────────────────────

class _ChildCard extends StatelessWidget {
  final String name;
  final String dob;
  final String details; // single line: "8.5 kg · 73 cm"
  final _CardStatus status;
  final bool present;
  final bool buckled;
  final bool near;
  final int battery;
  final String? photoPath;

  const _ChildCard({
    required this.name,
    required this.dob,
    required this.details,
    required this.status,
    this.present = true,
    required this.buckled,
    required this.near,
    required this.battery,
    this.photoPath,
  });

  Color get _badgeColor => switch (status) {
        _CardStatus.safe    => AppColors.safe,               // green
        _CardStatus.caution => const Color(0xFFE6A817),      // yellow/amber
        _CardStatus.warning => AppColors.warning,            // red
      };

  String get _badgeLabel => switch (status) {
        _CardStatus.safe    => 'SAFE',
        _CardStatus.caution => 'CAUTION',
        _CardStatus.warning => 'WARNING',
      };

  // Per-indicator tones — each pill colours itself independently.
  StatusTone get _buckleTone  => buckled      ? StatusTone.good : StatusTone.bad;
  StatusTone get _nearTone    => near         ? StatusTone.good : StatusTone.bad;
  StatusTone get _batteryTone => battery > 20 ? StatusTone.neutral : StatusTone.bad;

  @override
  Widget build(BuildContext context) {
    final warning = present && status == _CardStatus.warning;

    final headerGradient = warning
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0685F), Color(0xFFC2291D)],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // Lighter take on kHeaderGradient (headerTop → headerBottom)
            colors: [Color(0xFF4DBAD4), Color(0xFFA8E0EF)],
            stops: [0.31, 0.88],
          );

    final shadowColor =
        (warning ? const Color(0xFFC2291D) : AppColors.headerTop).withAlpha(36);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Gradient wave-header (identity) ──
            Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: headerGradient),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _CardHeaderWavePainter(
                        back: Colors.white.withAlpha(20),
                        front: Colors.white.withAlpha(36),
                      ),
                    ),
                  ),
                ),
                // Soft fade so the header melts into the white body (no hard seam)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 48,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withAlpha(0),
                            Colors.white.withAlpha(90),
                            Colors.white,
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(160),
                        ),
                        child: SignedAvatar(
                          photoPath: photoPath,
                          radius: 24,
                          backgroundColor: const Color(0xFFE8F6FB),
                          iconColor: AppColors.navy,
                          fallbackText: name.isNotEmpty ? name[0] : '?',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy)),
                            const SizedBox(height: 2),
                            Text(dob,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.navy.withAlpha(170),
                                    height: 1.3)),
                            Text(details,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.navy.withAlpha(170),
                                    height: 1.3)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusChip(),
                    ],
                  ),
                ),
              ],
            ),
            // ── White body (status indicators stay high-contrast) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: !present
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.child_care_outlined,
                            size: 18, color: AppColors.textSecondary),
                        SizedBox(width: 6),
                        Text('No baby detected',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                            child: StatusPill(
                          icon: buckled ? Icons.link : Icons.link_off,
                          label: buckled ? 'Buckled' : 'Unbuckled',
                          tone: _buckleTone,
                        )),
                        const SizedBox(width: 8),
                        Expanded(
                            child: StatusPill(
                          icon: near ? Icons.location_on : Icons.location_off,
                          label: near ? 'Near' : 'Far',
                          tone: _nearTone,
                        )),
                        const SizedBox(width: 8),
                        Expanded(
                            child: StatusPill(
                          icon: battery <= 20
                              ? Icons.battery_alert
                              : Icons.battery_full,
                          label: '$battery%',
                          tone: _batteryTone,
                        )),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Status badge as a white chip with a colored dot + label — legible on any
  // header gradient (blue or red) and consistent with the Join Code chip.
  Widget _statusChip() {
    final label = present ? _badgeLabel : 'SEAT EMPTY';
    final color = present ? _badgeColor : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

// Translucent wave sweeping to the top-right of the child-card header.
class _CardHeaderWavePainter extends CustomPainter {
  const _CardHeaderWavePainter({required this.back, required this.front});
  final Color back;
  final Color front;

  Path _wave(Size s, double dy) {
    final w = s.width;
    final h = s.height;
    return Path()
      ..moveTo(w, h * (0.78 + dy))
      ..cubicTo(w * 0.86, h * (0.66 + dy), w * 0.84, h * (0.46 + dy),
          w * 0.70, h * (0.40 + dy))
      ..cubicTo(w * 0.58, h * (0.34 + dy), w * 0.56, h * (0.18 + dy),
          w * 0.44, h * (0.12 + dy))
      ..cubicTo(w * 0.39, h * (0.09 + dy), w * 0.37, h * (0.03 + dy),
          w * 0.35, h * dy)
      ..lineTo(w, h * dy)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_wave(size, 0.05), Paint()..color = back);
    canvas.drawPath(_wave(size, 0.0), Paint()..color = front);
  }

  @override
  bool shouldRepaint(covariant _CardHeaderWavePainter old) =>
      old.back != back || old.front != front;
}

/// Two-loop wave: small crest on the left, bigger crest on the right.
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final h = size.height;
    final w = size.width;

    path.lineTo(0, h - 10);

    // ── Left crest — flat, subtle bump ────────────────────────────────────
    path.cubicTo(
      w * 0.12, h - 10,
      w * 0.20, h - 22,
      w * 0.32, h - 18,
    );
    // Trough
    path.cubicTo(
      w * 0.40, h - 14,
      w * 0.47, h - 8,
      w * 0.54, h - 10,
    );

    // ── Right crest — gentle, flattened bump ──────────────────────────────
    path.cubicTo(
      w * 0.61, h - 12,
      w * 0.70, h - 26,
      w * 0.82, h - 22,
    );
    // Settle to right edge
    path.cubicTo(
      w * 0.90, h - 18,
      w * 0.96, h - 12,
      w, h - 12,
    );

    path.lineTo(w, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}

class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final rawBeforeCursor =
        newValue.text.substring(0, newValue.selection.end.clamp(0, newValue.text.length));
    final digitsBeforeCursor =
        rawBeforeCursor.replaceAll(RegExp(r'[^0-9]'), '').length;

    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 8) digits = digits.substring(0, 8);

    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) buf.write('/');
      buf.write(digits[i]);
    }
    final text = buf.toString();

    var seenDigits = 0;
    var cursor = text.length;
    for (int i = 0; i < text.length; i++) {
      if (seenDigits >= digitsBeforeCursor) {
        cursor = i;
        break;
      }
      if (text[i] != '/') seenDigits++;
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }
}