import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cplus/screens/topicdetails.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'content_quiz.dart';
import 'progressprovider.dart';

class CourseContentScreen extends StatefulWidget {
  final List<String> filenames;
  final String title;

  const CourseContentScreen({
    super.key,
    required this.filenames,
    required this.title,
  });

  @override
  State<CourseContentScreen> createState() => _CourseContentScreenState();
}

class _CourseContentScreenState extends State<CourseContentScreen> {
  List<Map<String, dynamic>> courseContent = [];
  List<String> fileL = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCourseContent();
  }

  Future<void> _loadCourseContent() async {
    List<Map<String, dynamic>> allTopics = [];
    Map<String, dynamic>? currentQuizData;

    for (String file in widget.filenames) {
      try {
        print("DEBUG: 🔍 Loading file: $file");
        setState(() {
          fileL.add(file);
        });
        String jsonString = await rootBundle.loadString(file);

        if (jsonString.isEmpty) {
          print("DEBUG: ⚠️ Empty JSON file: $file");
          continue;
        }

        Map<String, dynamic> jsonData = jsonDecode(jsonString);

        if (jsonData.isEmpty) {
          print("DEBUG: ❌ JSON data empty for file: $file");
          continue;
        }

        if (file.contains("/quiz/")) {
          if (jsonData.containsKey("questions") && jsonData["questions"] is List) {
            currentQuizData = {
              "isQuizTile": true,
              "quizData": List<Map<String, dynamic>>.from(jsonData["questions"]),
            };
            print("DEBUG: ✅ Quiz data added for $file");
          } else {
            print("DEBUG: ⚠️ Quiz key missing or incorrect format in: $file");
          }
        } else {
          allTopics.add({
            "title": jsonData["topic"] ?? "No Title",
            "sections": jsonData["sections"] ?? [],
            "file": file,
          });
        }
      } catch (e) {
        print("DEBUG: ❌ Error loading file: $file - $e");
      }
    }

    if (currentQuizData != null) {
      allTopics.add(currentQuizData);
    }

    setState(() {
      courseContent = allTopics;
      _isLoading = false;
    });

    print("DEBUG: 🏁 Course content loaded successfully!");
  }

  Future<void> _markFileAsRead(String topic, String file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('progress')
            .doc('readFiles')
            .set({
          '$topic:$file': true,
        }, SetOptions(merge: true));
        print("DEBUG: ✅ Marked file as read: $file for topic: $topic");
      } catch (e) {
        print("DEBUG: ❌ Error marking file as read: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double appBarHeight = MediaQuery.of(context).size.height * 0.20;
    double minHeight = 120.0;
    double maxHeight = 170.0;
    appBarHeight = appBarHeight.clamp(minHeight, maxHeight);

    double screenWidth = MediaQuery.of(context).size.width;
    double titleFontSize = (screenWidth * 0.05).clamp(18.0, 24.0);
    double subtitleFontSize = (screenWidth * 0.04).clamp(14.0, 18.0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(appBarHeight),
        child: AppBar(
          backgroundColor: Color(0xff023047),
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 30,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          flexibleSpace: Padding(
            padding: const EdgeInsets.fromLTRB(15, 60, 15, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Let's Learn C++!",
                        style: TextStyle(
                          fontSize: subtitleFontSize,
                          fontFamily: 'Poppins',
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.center,
                    child: Image.asset(
                      'assets/4.png',
                      fit: BoxFit.contain,
                      height: appBarHeight * 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            height: 200,
            color: Color(0xff023047),
          ),
          Container(
            margin: EdgeInsets.only(top: 10),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  spreadRadius: 1,
                )
              ],
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Consumer<ProgressProvider>(
              builder: (context, progressProvider, child) {
                return ListView.builder(
                  itemCount: courseContent.length,
                  itemBuilder: (context, index) {
                    var topic = courseContent[index];

                    if (topic.containsKey("isQuizTile") && topic["isQuizTile"] == true) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ElevatedButton(
                          onPressed: () {
                            var quizData = topic["quizData"] ?? [];
                            if (quizData.isEmpty) {
                              print("DEBUG: 🚨 No quiz data available!");
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => QuizScreen(
                                  quizData: quizData,
                                  courseTitle: widget.title,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xff023047),
                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            "Take Quiz",
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Poppins',
                              fontSize: 18,
                            ),
                          ),
                        ),
                      );
                    }

                    String file = topic["file"] ?? "";
                    bool isRead = progressProvider.isFileRead(widget.title, file);

                    return Card(
                      color: isRead ? Colors.teal[50] : Colors.white.withOpacity(0.9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                        title: Text(
                          topic["title"] ?? "No Title",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xff023047),
                            fontFamily: 'Poppins',
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xff023047)),
                        onTap: () {
                          _markFileAsRead(widget.title, file);
                          progressProvider.markFileRead(widget.title, file);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TopicDetailScreen(
                                title: topic["title"] ?? widget.title,
                                fileL: fileL,
                                currentIndex: index,
                                filesLength: fileL.length,
                                topic: widget.title, content: [],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}