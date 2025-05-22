import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../resources/helper_notifi.dart';

import '../screens/homepage.dart';
import '../screens/profile.dart';
import '../screens/interview.dart';
import '../screens/notification.dart';


class CustomBottomNavigation extends StatefulWidget {
  final int initialIndex;
  final String userName;

  const CustomBottomNavigation({
    super.key,
    required this.userName,
    this.initialIndex = 0,
  });

  @override
  State<CustomBottomNavigation> createState() => _CustomBottomNavigationState();
}

class _CustomBottomNavigationState extends State<CustomBottomNavigation> {
  int _selectedIndex = 0;
  final ValueNotifier<int> _unreadCountNotifier = ValueNotifier<int>(0);
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    NotificationHelper.initNotifications(widget.userName, context: context);
    _fetchUnreadCount();
  }

  Future<void> _fetchUnreadCount() async {
    if (_isFetching) return;
    _isFetching = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isFetching = false;
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('isUserReminder', isEqualTo: true)
          .where('isRead', isEqualTo: false)
          .orderBy('scheduledTime', descending: true)
          .get();
      if (mounted) {
        _unreadCountNotifier.value = snapshot.docs.length;
        print("In-app badge updated: ${snapshot.docs.length} unread reminders");
      }
    } catch (e) {
      print("Error fetching unread count: $e");
      if (mounted) {
        _unreadCountNotifier.value = 0;
      }
    } finally {
      _isFetching = false;
    }
  }

  @override
  void dispose() {
    _unreadCountNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double navHeight = (screenHeight * 0.08).clamp(60, 80);
    final double iconSize = (screenWidth * 0.06).clamp(24, 32);
    final double selectedIconSize = (screenWidth * 0.07).clamp(26, 34);
    final double selectedFontSize = (screenWidth * 0.035).clamp(12, 14);
    final double unselectedFontSize = (screenWidth * 0.028).clamp(10, 12);
    final double badgeSize = (screenWidth * 0.045).clamp(16, 20);
    final double badgeFontSize = (screenWidth * 0.025).clamp(8, 10);
    final double badgePadding = (screenWidth * 0.005).clamp(2, 3);

    print("DEBUG: Screen size: ${screenWidth}x${screenHeight}, navHeight: $navHeight, "
        "iconSize: $iconSize, selectedFontSize: $selectedFontSize");

    final List<Widget> items = [
      Homepage(userName: widget.userName),
      const InterviewQuestionsScreen(),
      NotificationDisplayPage(userName: widget.userName),
      ProfileScreen(userName: widget.userName),
    ];

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return items[_selectedIndex];
          },
        ),
        bottomNavigationBar: Container(
          height: navHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: (screenWidth * 0.01).clamp(3, 5),
                spreadRadius: (screenWidth * 0.005).clamp(2, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (int index) {
                if (mounted) {
                  setState(() {
                    _selectedIndex = index;
                  });
                  _fetchUnreadCount();
                  print("Navigation to index $index, badge updated");
                }
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: Color(0xff023047),
              unselectedItemColor: Colors.grey.shade600,
              showUnselectedLabels: true,
              elevation: 0,
              selectedLabelStyle: TextStyle(
                fontFamily: 'Poppins',
                fontSize: selectedFontSize,
                fontWeight: FontWeight.w500,
              ),
              unselectedLabelStyle: TextStyle(
                fontFamily: 'Poppins',
                fontSize: unselectedFontSize,
                fontWeight: FontWeight.w500,
              ),
              selectedIconTheme: IconThemeData(size: selectedIconSize),
              unselectedIconTheme: IconThemeData(size: iconSize),
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home, size: _selectedIndex == 0 ? selectedIconSize : iconSize),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.integration_instructions_rounded, size: _selectedIndex == 1 ? selectedIconSize : iconSize),
                  label: 'Prep Q/A',
                ),
                BottomNavigationBarItem(
                  icon: _buildNotificationIcon(
                    badgeSize: badgeSize,
                    badgeFontSize: badgeFontSize,
                    badgePadding: badgePadding,
                    iconSize: _selectedIndex == 2 ? selectedIconSize : iconSize,
                  ),
                  label: 'Notifications',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person, size: _selectedIndex == 3 ? selectedIconSize : iconSize),
                  label: 'Profile',
                ),
              ],
              landscapeLayout: BottomNavigationBarLandscapeLayout.spread,
              iconSize: iconSize,
              selectedFontSize: selectedFontSize,
              unselectedFontSize: unselectedFontSize,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon({
    required double badgeSize,
    required double badgeFontSize,
    required double badgePadding,
    required double iconSize,
  }) {
    return ValueListenableBuilder<int>(
      valueListenable: _unreadCountNotifier,
      builder: (context, unreadCount, child) {
        return Stack(
          alignment: Alignment.topRight,
          children: [
            Icon(Icons.notifications, size: iconSize),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: EdgeInsets.all(badgePadding),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(
                    minWidth: badgeSize,
                    minHeight: badgeSize,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: badgeFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}