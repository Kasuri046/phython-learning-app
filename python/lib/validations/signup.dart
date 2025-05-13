import 'package:cplus/validations/signin.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../resources/navigation_helper.dart';
import '../resources/shared_preferences.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _agreeToTerms = false;
  String? usernameError, emailError, passwordError, confirmPasswordError;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSigningUp = false;

  void _signup() async {
    if (_isSigningUp) return;
    setState(() {
      _isSigningUp = true;
      usernameError = emailError = passwordError = confirmPasswordError = null;
    });

    String username = _usernameController.text.trim();
    String email = _emailController.text.trim().toLowerCase();
    String password = _passwordController.text;
    String confirmPassword = _confirmPasswordController.text;

    RegExp usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
    RegExp emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

    if (username.isEmpty) {
      setState(() {
        usernameError = 'Please enter your username.';
        _isSigningUp = false;
      });
      return;
    }
    if (!usernameRegex.hasMatch(username)) {
      setState(() {
        usernameError = 'Use 3–20 characters, only letters, numbers, or underscore.';
        _isSigningUp = false;
      });
      return;
    }

    if (email.isEmpty) {
      setState(() {
        emailError = 'Please enter an email address.';
        _isSigningUp = false;
      });
      return;
    }
    if (!emailRegex.hasMatch(email)) {
      setState(() {
        emailError = 'Enter a valid email like name@example.com';
        _isSigningUp = false;
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        passwordError = 'Please create a password.';
        _isSigningUp = false;
      });
      return;
    }
    if (password.length < 8 || password.length > 20) {
      setState(() {
        passwordError = 'Password must be 8–20 characters.';
        _isSigningUp = false;
      });
      return;
    }

    if (confirmPassword.isEmpty) {
      setState(() {
        confirmPasswordError = 'Please enter your password again.';
        _isSigningUp = false;
      });
      return;
    }
    if (password != confirmPassword) {
      setState(() {
        confirmPasswordError = 'Passwords do not match. Try again.';
        _isSigningUp = false;
      });
      return;
    }

    if (!_agreeToTerms) {
      showErrorSnackbar("Please agree to the terms to continue.");
      setState(() => _isSigningUp = false);
      return;
    }

    User? user;
    try {
      // Create user in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = userCredential.user;
      if (user == null) {
        throw Exception('User creation failed: No user returned.');
      }
      print("✅ Created Firebase Auth user: uid=${user.uid}, email=$email");

      // Set displayName in Firebase Auth
      await user.updateDisplayName(username);
      print("✅ Set Firebase Auth displayName: '$username'");

      // Save to Firestore
      DocumentReference userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      WriteBatch batch = FirebaseFirestore.instance.batch();
      batch.set(
        userDoc,
        {
          'email': email,
          'displayName': username,
          'progress': 0,
          'signInMethod': 'password',
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();
      print("✅ Saved user to Firestore: uid=${user.uid}, displayName='$username'");

      // Save username to SharedPreferences
      await SharedPrefHelper.setUserName(username);
      print("✅ Saved username to SharedPreferences: '$username'");

      _clearFields();
      showSuccessSnackbar("Registered Successfully!");
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        NavigationHelper.pushReplacementWithFade(context, const Signin());
      }
    } on FirebaseAuthException catch (e) {
      final Map<String, String> firebaseErrors = {
        'email-already-in-use': 'That email is already registered. Try logging in.',
        'invalid-email': 'That email doesn’t look right. Check the format.',
        'weak-password': 'Try a stronger password – at least 8 characters.',
        'network-request-failed': 'Please check your internet connection.',
        'too-many-requests': 'Too many attempts – please try again later.',
      };
      String errorMsg = firebaseErrors[e.code] ?? 'Authentication failed. Please try again.';
      showErrorSnackbar(errorMsg);
      print("⚠️ FirebaseAuthException: code=${e.code}, message=${e.message}");
      // Cleanup partial user if created
      if (user != null) {
        try {
          await user.delete();
          print("🗑️ Deleted partial Auth user: uid=${user.uid}");
        } catch (deleteError) {
          print("⚠️ Failed to delete partial user: $deleteError");
        }
      }
    } on FirebaseException catch (e) {
      String errorMsg = 'Firestore error: ${e.message ?? "Unknown error."}';
      if (e.code == 'permission-denied') {
        errorMsg = 'Unable to save user data. Contact support.';
      }
      showErrorSnackbar(errorMsg);
      print("⚠️ FirebaseException: code=${e.code}, message=${e.message}");
      // Cleanup partial user
      if (user != null) {
        try {
          await user.delete();
          print("🗑️ Deleted partial Auth user: uid=${user.uid}");
        } catch (deleteError) {
          print("⚠️ Failed to delete partial user: $deleteError");
        }
      }
    } catch (e, stackTrace) {
      showErrorSnackbar('Something went wrong. Please try again.');
      print("⚠️ Unexpected error: $e\nStackTrace: $stackTrace");
      // Cleanup partial user
      if (user != null) {
        try {
          await user.delete();
          print("🗑️ Deleted partial Auth user: uid=${user.uid}");
        } catch (deleteError) {
          print("⚠️ Failed to delete partial user: $deleteError");
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSigningUp = false);
      }
    }
  }

  void showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _clearFields() {
    _usernameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    setState(() {
      _agreeToTerms = false;
    });
  }

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,
          title: const Text(
            'Terms and Conditions',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xff023047),
            ),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.55,
            child: Scrollbar(
              child: SingleChildScrollView(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.6,
                    ),
                    children: [
                      TextSpan(text: 'Welcome to the HTML Learning App!\n\n'),
                      TextSpan(text: 'By using our application, you agree to the following Terms and Conditions. Please read them carefully.\n\n'),

                      TextSpan(
                        text: '1. Acceptance of Terms\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: 'By accessing or using the HTML Learning App, you agree to be bound by these Terms and Conditions, including our Privacy Policy.\n\n'),

                      TextSpan(
                        text: '2. User Accounts\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: '- You must create an account to access certain features.\n- Maintain confidentiality of credentials.\n- Provide accurate information.\n- We may suspend accounts violating these terms.\n\n'),

                      TextSpan(
                        text: '3. Content and Usage\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: '- Content is for educational purposes only.\n- Do not reproduce or distribute without permission.\n- No unlawful or prohibited use.\n\n'),

                      TextSpan(
                        text: '4. User Conduct\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: '- Do not harm, spam, or upload malicious content.\n- We may restrict access for violations.\n\n'),

                      TextSpan(
                        text: '5. Privacy\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: 'By using the app, you consent to our data practices outlined in the Privacy Policy.\n\n'),

                      TextSpan(
                        text: '6. Limitation of Liability\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: '- App is provided "as is" without warranties.\n- We are not liable for usage-related damages.\n\n'),

                      TextSpan(
                        text: '7. Modifications\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: '- Terms may be updated without prior notice.\n- Continued use means acceptance of updates.\n\n'),

                      TextSpan(
                        text: '8. Termination\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: '- We may terminate access at our discretion.\n- Data may be deleted upon termination.\n\n'),

                      TextSpan(
                        text: '9. Governing Law\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: '- Governed by laws of [Your Country/Region].\n- Disputes will be resolved in [Your Jurisdiction].\n\n'),

                      TextSpan(
                        text: '10. Contact Us\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: 'For queries, email us at support@htmllearningapp.com\n\n'),

                      TextSpan(
                        text: 'Last updated: May 5, 2025\n',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Color(0xff023047),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _agreeToTerms = true;
                });
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff023047),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              child: const Text(
                'I Agree',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double padding = screenSize.width * 0.05;
    final double containerWidth = screenSize.width * 0.9;
    final double textFieldHeight = screenSize.height * 0.07;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/des.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SingleChildScrollView(
            child: Center(
              child: Container(
                width: containerWidth,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 130),
                    const Text(
                      'Signup to get Started!',
                      style: TextStyle(
                        color: Color(0xff023047),
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 40),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: textFieldHeight,
                            child: _buildTextField(
                              controller: _usernameController,
                              hintText: 'Username',
                              prefixIcon: Icons.person_outline,
                              height: textFieldHeight,
                            ),
                          ),
                          if (usernameError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 5, left: 5),
                              child: Text(
                                usernameError!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: padding),
                      child: Column(
                        children: [
                          SizedBox(
                            height: textFieldHeight,
                            child: _buildTextField(
                              controller: _emailController,
                              hintText: 'Your Email',
                              prefixIcon: Icons.email_outlined,
                              height: textFieldHeight,
                            ),
                          ),
                          if (emailError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                emailError!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: padding),
                      child: Column(
                        children: [
                          SizedBox(
                            height: textFieldHeight,
                            child: _buildTextField(
                              controller: _passwordController,
                              hintText: 'Create Password',
                              prefixIcon: Icons.lock_outline,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Color(0xff023047),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              height: textFieldHeight,
                            ),
                          ),
                          if (passwordError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                passwordError!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: padding),
                      child: Column(
                        children: [
                          SizedBox(
                            height: textFieldHeight,
                            child: _buildTextField(
                              controller: _confirmPasswordController,
                              hintText: 'Confirm Password',
                              prefixIcon: Icons.lock_outline,
                              obscureText: _obscureConfirmPassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Color(0xff023047),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                  });
                                },
                              ),
                              height: textFieldHeight,
                            ),
                          ),
                          if (confirmPasswordError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                confirmPasswordError!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Checkbox(
                          value: _agreeToTerms,
                          onChanged: (bool? value) {
                            setState(() {
                              _agreeToTerms = value ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'I have read and agree with ',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                WidgetSpan(
                                  child: GestureDetector(
                                    onTap: _showTermsAndConditions,
                                    child: const Text(
                                      'Terms and Conditions',
                                      style: TextStyle(
                                        color: Color(0xff023047),
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _isSigningUp ? null : _signup,
                      child: Container(
                        height: 50,
                        width: containerWidth,
                        decoration: BoxDecoration(
                          color: Color(0xff023047),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: _isSigningUp
                              ? const SizedBox(
                            width: 22,
                            height: 24,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 3,
                            ),
                          )
                              : const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already Registered? ",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        InkWell(
                          onTap: () => NavigationHelper.pushReplacementWithFade(
                              context, const Signin()),
                          child: const Text(
                            "Log In",
                            style: TextStyle(
                              color: Color(0xff023047),
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    IconData? prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    required double height,
  }) {
    return SizedBox(
      height: height,
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.black, fontFamily: 'Poppins'),
        obscureText: obscureText,
        textAlign: TextAlign.left,
        decoration: InputDecoration(
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Color(0xff023047)) : null,
          suffixIcon: suffixIcon,
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.grey, fontFamily: 'Poppins'),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xff023047)),
          ),
        ),
      ),
    );
  }
}