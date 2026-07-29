import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../models/car.dart';
import '../services/alert_service.dart';
import '../services/car_service.dart';
import '../services/family_service.dart';
import '../widgets/alert_bottom_sheet.dart';
import 'existing_or_new_family_screen.dart';
import 'home_screen.dart';
import 'contacts_screen.dart';
import 'settings_screen.dart';

/// Wraps the app's main tabs in a bottom navigation bar.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  RealtimeChannel? _profileChannel;
  StreamSubscription<List<ActiveAlert>>? _alertSub;

  final List<Widget> _pages = [
    const HomeScreen(),
    ContactsScreen(showBack: false),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _watchMyProfile();
    _alertSub = AlertService.instance.activeAlertsStream.listen(_onAlerts);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskAboutCar());
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    _profileChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _maybeAskAboutCar() async {
    try {
      final cars = await CarService().myCars();
      if (cars.isEmpty || !mounted) return;

      final activeId = await FamilyService().getActiveCarId();
      Car? active;
      if (activeId != null) {
        for (final c in cars) {
          if (c.id == activeId) {
            active = c;
            break;
          }
        }
      }
      if (!mounted) return;

      if (active != null) {
        final keepUsing = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Which car today?',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
            content: Text('Are you using "${active!.name}" today?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Change'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Yes'),
              ),
            ],
          ),
        );
        if (keepUsing == true || !mounted) return;
      }

      await _pickActiveCar(cars, active);
    } catch (_) {
      // Non-fatal — skip the prompt silently on any failure.
    }
  }

  Future<void> _pickActiveCar(List<Car> cars, Car? current) async {
    final chosen = await showModalBottomSheet<Car>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
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
                    color: Colors.black12, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Which car are you using?',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy)),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: cars.length,
                itemBuilder: (_, i) {
                  final c = cars[i];
                  final selected = current?.id == c.id;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: carColorFromHex(c.color),
                      radius: 12,
                    ),
                    title: Text(c.name),
                    subtitle: (c.plateNumber != null && c.plateNumber!.isNotEmpty)
                        ? Text(c.plateNumber!)
                        : null,
                    trailing: selected
                        ? const Icon(Icons.check_circle, color: AppColors.accent, size: 20)
                        : null,
                    onTap: () => Navigator.of(ctx).pop(c),
                  );
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
          ],
        ),
      ),
    );
    if (chosen != null) {
      await FamilyService().setActiveCar(chosen.id);
    }
  }

  void _onAlerts(List<ActiveAlert> alerts) {
    if (alerts.isEmpty || AlertService.instance.sheetOpen || !mounted) return;
    showAlertBottomSheet(context, initial: alerts);
  }

  void _watchMyProfile() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    _profileChannel = Supabase.instance.client
        .channel('profile-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: uid,
          ),
          callback: (payload) {
            final newFamily = payload.newRecord['family_id'];
            if (newFamily == null && mounted) {
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  title: const Text('Removed from family'),
                  content: const Text(
                    'You are no longer part of this family.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) =>
                                const ExistingOrNewFamilyScreen(),
                          ),
                          (_) => false,
                        );
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppState.mainTabIndex,
      builder: (context, index, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: IndexedStack(index: index, children: _pages),
          bottomNavigationBar: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: BottomNavigationBar(
              currentIndex: index,
              onTap: (i) => AppState.mainTabIndex.value = i,
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              iconSize: 28,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white.withValues(alpha: 0.70),
              selectedFontSize: 12,
              unselectedFontSize: 12,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'Home'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.groups_outlined),
                    activeIcon: Icon(Icons.groups),
                    label: 'Family'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.settings_outlined),
                    activeIcon: Icon(Icons.settings),
                    label: 'Settings'),
              ],
            ),
          ),
        );
      },
    );
  }
}
