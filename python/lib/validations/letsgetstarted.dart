import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cplus/validations/signin.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cplus/validations/signup.dart';
import 'package:flutter/material.dart';
import '../components/bottom_navigation.dart';
import '../resources/shared_preferences.dart';

class Start extends StatefulWidget {
  const Start({super.key});

  @override
  _StartState createState() => _StartState();
}

class _StartState extends State<Start> {
  bool _isLoading = false; // Track loading state

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    bool isLoggedIn = await SharedPrefHelper.isLoggedIn();
    User? user = FirebaseAuth.instance.currentUser;

    if (isLoggedIn && user != null) {
      String displayName = await _getDisplayName(user);
      print("✅ Logged in, navigating with displayName='$displayName'");
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CustomBottomNavigation(userName: displayName),
          ),
        );
      }
    } else if (isLoggedIn && user == null) {
      // Reset SharedPreferences if isLoggedIn is true but no user exists
      await SharedPrefHelper.clearAll();
      print("DEBUG: Cleared SharedPreferences due to no authenticated user");
    }
  }

  Future<String> _getDisplayName(User? user) async {
    if (user == null) {
      print("⚠️ No user signed in");
      return "Guest";
    }

    String email = user.email?.toLowerCase() ?? "";
    String displayName = user.displayName ?? (await SharedPrefHelper.getUserName()) ?? "Guest";

    // Check Firestore
    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists) {
      var data = doc.data() as Map<String, dynamic>;
      displayName = data['displayName'] ?? data['name'] ?? displayName;
      print("🔍 Firestore displayName: '$displayName' for uid=${user.uid}, email='$email'");
    }

    // Sync Firebase Auth
    if (user.displayName != displayName) {
      await user.updateDisplayName(displayName);
      print("✅ Synced Firebase Auth displayName to: '$displayName'");
    }

    await SharedPrefHelper.setUserName(displayName);
    return displayName;
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    if (_isLoading) return; // Prevent multiple clicks

    setState(() {
      _isLoading = true; // Start loading
    });

    final GoogleSignIn googleSignIn = GoogleSignIn();
    final FirebaseAuth auth = FirebaseAuth.instance;

    try {
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sign-in canceled.',
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Poppins',
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _isLoading = false; // Stop loading
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        String displayName = user.displayName ?? 'No Name';
        String email = user.email?.toLowerCase() ?? '';

        // Check Firestore for existing displayName
        QuerySnapshot query = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          var existing = query.docs.first.data() as Map<String, dynamic>;
          displayName = existing['displayName'] ?? existing['name'] ?? displayName;
          print("🔍 Found existing user for '$email', using displayName: '$displayName'");
        }

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': email,
          'displayName': displayName,
          'signInMethod': 'google',
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print("✅ Saved Google user: uid=${user.uid}, displayName='$displayName'");

        // Sync Firebase Auth
        if (user.displayName != displayName) {
          await user.updateDisplayName(displayName);
          print("✅ Synced Firebase Auth displayName to: '$displayName'");
        }

        await SharedPrefHelper.setLoggedIn(true);
        await SharedPrefHelper.setUserName(displayName);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Welcome, $displayName!',
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Poppins',
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xff023047),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );

        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CustomBottomNavigation(userName: displayName),
            ),
          );
        }
      }
    } catch (e) {
      print("⚠️ Google Sign-In error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sign-in failed. Please check your network and try again.',
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Poppins',
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Stop loading
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 600; // Phone vs. tablet/desktop

    // Responsive padding and font sizes
    final horizontalPadding = screenWidth * 0.05; // 5% of screen width
    final verticalSpacing = screenHeight * 0.02; // 2% of screen height
    final titleFontSize = (screenWidth * 0.06).clamp(18.0, 24.0); // 18-24px
    final buttonFontSize = (screenWidth * 0.04).clamp(14.0, 16.0); // 14-16px
    final buttonHeight = screenHeight * 0.07; // 7% of screen height
    final buttonWidth = isSmallScreen ? screenWidth * 0.9 : screenWidth * 0.42; // Full-width or side-by-side

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image, scaled to contain
          Image.asset(
            'assets/pyt.png',
            fit: BoxFit.cover, // Changed to contain to avoid distortion
            width: screenWidth,
            height: screenHeight,
          ),
          // Main content
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title
                Padding(
                  padding: EdgeInsets.only(top: screenHeight * 0.2), // 20% from top
                  child: Text(
                    'Let\'s Get Started',
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontFamily: 'Poppins',
                      color: const Color(0xff023047),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: verticalSpacing * 2),
                // Social sign-in button
                if (Platform.isAndroid)
                  _buildSocialButton(
                    context,
                    'Continue With Google',
                    'assets/img.png',
                    _isLoading,
                    buttonWidth,
                    buttonHeight,
                    buttonFontSize,
                        () => _handleGoogleSignIn(context),
                  )
                else if (Platform.isIOS)
                  _buildSocialButton(
                    context,
                    'Continue With Apple',
                    'assets/apple.png',
                    false, // Apple sign-in not implemented
                    buttonWidth,
                    buttonHeight,
                    buttonFontSize,
                        () {},
                  ),
                SizedBox(height: verticalSpacing),
                // Divider with "or"
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        thickness: 1,
                        color: Colors.grey,
                        indent: horizontalPadding * 0.5,
                        endIndent: horizontalPadding * 0.5,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding * 0.5),
                      child: Text(
                        "or",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: buttonFontSize * 0.9,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        thickness: 1,
                        color: Colors.grey,
                        indent: horizontalPadding * 0.5,
                        endIndent: horizontalPadding * 0.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: verticalSpacing),
                // Log In and Sign Up buttons
                isSmallScreen
                    ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionButton(
                      context,
                      'Log In',
                      const Color(0xff023047),
                      const Signin(),
                      buttonWidth,
                      buttonHeight,
                      buttonFontSize,
                    ),
                    SizedBox(height: verticalSpacing),
                    _buildActionButton(
                      context,
                      'Sign Up',
                      const Color(0xff023047),
                      const Signup(),
                      buttonWidth,
                      buttonHeight,
                      buttonFontSize,
                    ),
                  ],
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      context,
                      'Log In',
                      const Color(0xff023047),
                      const Signin(),
                      buttonWidth,
                      buttonHeight,
                      buttonFontSize,
                    ),
                    _buildActionButton(
                      context,
                      'Sign Up',
                      const Color(0xff023047),
                      const Signup(),
                      buttonWidth,
                      buttonHeight,
                      buttonFontSize,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton(
      BuildContext context,
      String title,
      String imagePath,
      bool isLoading,
      double buttonWidth,
      double buttonHeight,
      double fontSize,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: isLoading ? null : onTap, // Disable tap when loading
      child: Container(
        width: buttonWidth,
        height: buttonHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xff023047)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isLoading) ...[
              Image.asset(
                imagePath,
                height: buttonHeight * 0.5, // 50% of button height
              ),
              SizedBox(width: buttonWidth * 0.03),
              Text(
                title,
                style: TextStyle(
                  color: isLoading ? Colors.grey : Colors.black,
                  fontFamily: 'Poppins',
                  fontSize: fontSize,
                ),
              ),
            ] else ...[
              SizedBox(
                width: buttonHeight * 0.5,
                height: buttonHeight * 0.5,
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xff023047)),
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: buttonWidth * 0.03),
              Text(
                'Signing In...',
                style: TextStyle(
                  color: Colors.grey,
                  fontFamily: 'Poppins',
                  fontSize: fontSize,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context,
      String title,
      Color color,
      Widget navigateTo,
      double buttonWidth,
      double buttonHeight,
      double fontSize,
      ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => navigateTo));
      },
      child: Container(
        width: buttonWidth,
        height: buttonHeight,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Poppins',
              fontSize: fontSize,
            ),
          ),
        ),
      ),
    );
  }
}