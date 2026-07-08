import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';
import '../models/seat_status.dart';
import '../models/child.dart';
import '../services/alert_service.dart';
import '../services/child_service.dart';
import 'alert_screen.dart';
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
  int _index = 0;
  RealtimeChannel? _profileChannel;
  StreamSubscription<AlertEvent>? _alertSub;
  StreamSubscription<List<Child>>? _childrenSub;
  bool _alertShowing = false;
  String? _firstChildName;

  final ChildService _childService = ChildService();

  final List<Widget> _pages = [
    const HomeScreen(),
    ContactsScreen(showBack: false),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _watchMyProfile();
    _alertSub = AlertService.instance.alertStream.listen(_onAlert);
    _childrenSub = _childService.myChildrenStream().listen((children) {
      _firstChildName = children.isNotEmpty ? children.first.name : null;
    });
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    _childrenSub?.cancel();
    _profileChannel?.unsubscribe();
    super.dispose();
  }

  void _onAlert(AlertEvent event) {
    if (event.severity == SeatSeverity.safe || _alertShowing || !mounted) return;
    _alertShowing = true;
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => AlertScreen(
              event: event,
              childName: _firstChildName,
            ),
          ),
        )
        .then((_) => _alertShowing = false);
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: IndexedStack(index: _index, children: _pages),
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
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          iconSize: 28,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white.withOpacity(0.70),
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
  }
}
