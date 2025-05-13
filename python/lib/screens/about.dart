import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(100),
        child: AppBar(
          backgroundColor: Color(0xff023047),
          elevation: 0, // Keeps the flat look
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context), // Back navigation
          ),
          title: Padding(
            padding: const EdgeInsets.only(top: 0), // Adjusted padding for title
            child: const Text(
              'About',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          centerTitle: true,
        ),
      ),
      body: Stack(
        children: [
          Container(
            height: 50,
            color: Color(0xff023047),
          ),
          Container(
            margin: const EdgeInsets.only(top: 10,), // Adjusted margins
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30), // Rounded corners
            ),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                // Wrapping the entire content in a container with a light teal background
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.blue[50], // Light teal background
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: _buildPrivacyPolicyContent(),
                ),
                const SizedBox(height: 20), // Added spacing before button
                ElevatedButton(
                  onPressed: () {
                    // Action when user agrees to privacy policy
                    Navigator.pop(context); // Go back on button press
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:Color(0xff023047),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text(
                    'I Agree',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPolicyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About the App\n',
          style: const TextStyle(
            fontSize: 16,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This application is designed to help beginners learn the fundamentals of C++ programming in an easy and interactive way. Whether you are a student or someone looking to start coding, this app provides the essential tools to get started.\n',
          style: const TextStyle(
            fontSize: 14,
            fontFamily: 'Poppins',
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'What You’ll Learn\n',
          style: const TextStyle(
            fontSize: 16,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '• Basic syntax and structure of C++\n'
              '• Variables, data types, and operators\n'
              '• Conditional statements and loops\n'
              '• Functions and arrays\n'
              '• Object-Oriented Programming concepts\n',
          style: const TextStyle(
            fontSize: 14,
            fontFamily: 'Poppins',
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Our Mission\n',
          style: const TextStyle(
            fontSize: 16,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Our goal is to make programming accessible to everyone, regardless of background. This app is structured to guide you step-by-step with lessons, quizzes, and hands-on code practice.\n',
          style: const TextStyle(
            fontSize: 14,
            fontFamily: 'Poppins',
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Support and Feedback\n',
          style: const TextStyle(
            fontSize: 16,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We continuously improve the app based on user feedback. If you have suggestions, find bugs, or want to contribute ideas, feel free to reach out:\n'
              '• Email: cpp.learn@appsupport.com\n'
              '• Instagram: @cpp.learn\n',
          style: const TextStyle(
            fontSize: 14,
            fontFamily: 'Poppins',
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Disclaimer\n',
          style: const TextStyle(
            fontSize: 16,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This app is for educational purposes only. While we strive to ensure accuracy, users are encouraged to cross-check concepts and practice coding regularly.\n',
          style: const TextStyle(
            fontSize: 14,
            fontFamily: 'Poppins',
            color: Colors.black54,
            height: 1.5,
          ),
        ),
      ],
    );
  }

}