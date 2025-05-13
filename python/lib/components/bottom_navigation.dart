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
    final List<Widget> items = [
      Homepage(userName: widget.userName),
      const InterviewQuestionsScreen(),
      NotificationDisplayPage(userName: widget.userName),
      ProfileScreen(userName: widget.userName),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: items[_selectedIndex],
      bottomNavigationBar: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 3,
              spreadRadius: 2,
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
            selectedLabelStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.integration_instructions_rounded),
                label: 'Prep Q/A',
              ),
              BottomNavigationBarItem(
                icon: _buildNotificationIcon(),
                label: 'Notifications',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return ValueListenableBuilder<int>(
      valueListenable: _unreadCountNotifier,
      builder: (context, unreadCount, child) {
        return Stack(
          alignment: Alignment.topRight,
          children: [
            const Icon(Icons.notifications),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
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