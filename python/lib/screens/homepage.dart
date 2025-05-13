import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cplus/screens/progressprovider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/custom_drawer.dart';
import '../resources/shared_preferences.dart';
import 'coursecontent.dart';

extension StringExtension on String {
  String capitalizeWords() {
    if (isEmpty) return this;
    return split(' ')
        .map((word) => word.isNotEmpty
        ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
        : word)
        .join(' ');
  }
}

class Homepage extends StatefulWidget {
  final String userName;
  const Homepage({super.key, required this.userName});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final PageController _pageController = PageController();
  String displayName = "Learner";
  Set<String> _openedTopics = {};

  @override
  void initState() {
    super.initState();
    _fetchAndSetUserName();
    _loadOpenedTopics();
    print("DEBUG: Homepage initialized, userName: ${widget.userName}");
  }

  Future<void> _loadOpenedTopics() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('progress')
          .doc('openedTopics')
          .get();
      if (doc.exists) {
        List<String>? opened = List<String>.from(doc['topics'] ?? []);
        if (mounted) { // Check if widget is still mounted
          setState(() {
            _openedTopics = opened.toSet();
          });
        }
        print("DEBUG: Loaded opened topics from Firestore: $_openedTopics");
      }
    }
  }

  Future<void> _saveOpenedTopic(String topic) async {
    if (!_openedTopics.contains(topic)) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _openedTopics.add(topic);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('progress')
            .doc('openedTopics')
            .set({
          'topics': _openedTopics.toList(),
        }, SetOptions(merge: true));
        print("DEBUG: Saved opened topic to Firestore: $topic");
        if (mounted) { // Check if widget is still mounted
          setState(() {});
        }
      }
    }
  }

  Future<void> _fetchAndSetUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    print("DEBUG: Fetching username... User: ${user?.uid ?? 'No user'}");

    if (user != null) {
      print("DEBUG: widget.userName: ${widget.userName}");
      if (widget.userName.isNotEmpty && widget.userName.toLowerCase() != 'learner' && widget.userName.toLowerCase() != 'user') {
        setState(() {
          displayName = widget.userName.capitalizeWords();
        });
        await SharedPrefHelper.setUserName(widget.userName);
        print("DEBUG: Set displayName from widget.userName: $displayName");
        return;
      }

      String? authName = user.displayName;
      print("DEBUG: Firebase Auth displayName: $authName");
      if (authName != null && authName.isNotEmpty && authName.toLowerCase() != 'learner' && authName.toLowerCase() != 'user') {
        setState(() {
          displayName = authName.capitalizeWords();
        });
        await SharedPrefHelper.setUserName(authName);
        print("DEBUG: Set displayName from Firebase Auth: $displayName");
        return;
      }

      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        print("DEBUG: Firestore fetch attempted. Doc exists: ${userDoc.exists}");
        if (userDoc.exists) {
          var data = userDoc.data() as Map<String, dynamic>?;
          String fetchedName = data?['displayName'] ?? data?['name'] ?? '';
          print("DEBUG: Firestore displayName: $fetchedName");
          if (fetchedName.isNotEmpty && fetchedName.toLowerCase() != 'learner' && fetchedName.toLowerCase() != 'user') {
            setState(() {
              displayName = fetchedName.capitalizeWords();
            });
            await SharedPrefHelper.setUserName(fetchedName);
            if (user.displayName != fetchedName) {
              await user.updateDisplayName(fetchedName);
              print("DEBUG: Synced Firebase Auth displayName: $fetchedName");
            }
            print("DEBUG: Set displayName from Firestore: $displayName");
            return;
          }
        }
      } catch (e) {
        print("DEBUG: Error fetching from Firestore: $e");
      }

      String? storedName = await SharedPrefHelper.getUserName();
      print("DEBUG: Stored name from SharedPreferences: $storedName");
      if (storedName != null && storedName.isNotEmpty && storedName.toLowerCase() != 'learner' && storedName.toLowerCase() != 'user') {
        setState(() {
          displayName = storedName.capitalizeWords();
        });
        print("DEBUG: Set displayName from SharedPreferences: $displayName");
        return;
      }

      setState(() {
        displayName = "Learner";
      });
      await SharedPrefHelper.setUserName("Learner");
      print("DEBUG: Set displayName to default: $displayName");
    } else {
      setState(() {
        displayName = "Learner";
      });
      await SharedPrefHelper.setUserName("Learner");
      print("DEBUG: No user logged in. Set displayName to default: $displayName");
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    print("DEBUG: Homepage disposed");
    super.dispose();
  }

  final List<Map<String, dynamic>> courses = [
    {'icon': Icons.code, 'title': 'Python Syntax & Basics'},
    {'icon': Icons.comment, 'title': 'Comments & Variables'},
    {'icon': Icons.data_object, 'title': 'Data Types & Casting'},
    {'icon': Icons.calculate, 'title': 'Operators & Booleans'},
    {'icon': Icons.list, 'title': 'Lists & Arrays'},
    {'icon': Icons.table_rows, 'title': 'Tuples'},
    {'icon': Icons.account_box, 'title': 'Sets'},
    {'icon': Icons.book, 'title': 'Dictionaries'},
    {'icon': Icons.compare_arrows, 'title': 'Conditions & Match'},
    {'icon': Icons.repeat, 'title': 'Loops'},
    {'icon': Icons.functions, 'title': 'Functions & Lambda'},
    {'icon': Icons.class_, 'title': 'Classes & OOP'},
    {'icon': Icons.text_fields, 'title': 'Strings & Input'},
    {'icon': Icons.search, 'title': 'Regular Expressions & JSON'},
    {'icon': Icons.cloud, 'title': 'Advanced Python'},
  ];

  final Map<String, List<String>> topicSubtopicFiles = {
    'Python Syntax & Basics': [
      'assets/python_topics/00_python_syntax.json',
      'assets/python_topics/01_python_comments.json',
      'assets/quiz/Quiz_Python_Syntax.json', // Placeholder: Create if needed
    ],
    'Comments & Variables': [
      'assets/python_topics/02_python_variables.json',
      'assets/python_topics/03_python_variables_names.json',
      'assets/python_topics/04_python_variables_multiple.json',
      'assets/python_topics/05_python_variables_output.json',
      'assets/python_topics/06_python_variables_global.json',
      'assets/python_topics/07_python_variables_exercises.json',
      'assets/quiz/Quiz_Variables.json', // Placeholder
    ],
    'Data Types & Casting': [
      'assets/python_topics/08_python_datatypes.json',
      'assets/python_topics/09_python_numbers.json',
      'assets/python_topics/10_python_casting.json',
      'assets/quiz/Quiz_Data_Types.json', // Placeholder
    ],
    'Operators & Booleans': [
      'assets/python_topics/12_python_booleans.json',
      'assets/python_topics/13_python_operators.json',
      'assets/quiz/Quiz_Operators.json', // Placeholder
    ],
    'Lists & Arrays': [
      'assets/python_topics/14_python_lists.json',
      'assets/python_topics/15_python_lists_access.json',
      'assets/python_topics/16_python_lists_change.json',
      'assets/python_topics/17_python_lists_add.json',
      'assets/python_topics/18_python_lists_remove.json',
      'assets/python_topics/52_python_arrays.json',
      'assets/quiz/Quiz_Lists.json', // Placeholder
    ],
    'Tuples': [
      'assets/python_topics/25_python_tuples.json',
      'assets/python_topics/26_python_tuples_access.json',
      'assets/python_topics/27_python_tuples_update.json',
      'assets/python_topics/28_python_tuples_unpack.json',
      'assets/python_topics/30_python_tuples_join.json',
      'assets/quiz/Quiz_Tuples.json', // Placeholder
    ],
    'Sets': [
      'assets/python_topics/31_python_sets.json',
      'assets/python_topics/32_python_sets_access.json',
      'assets/python_topics/33_python_sets_add.json',
      'assets/python_topics/34_python_sets_remove.json',
      'assets/python_topics/35_python_sets_loop.json',
      'assets/python_topics/36_python_sets_join.json',
      'assets/quiz/Quiz_Sets.json', // Placeholder
    ],
    'Dictionaries': [
      'assets/python_topics/37_python_dictionaries.json',
      'assets/python_topics/38_python_dictionaries_access.json',
      'assets/python_topics/39_python_dictionaries_change.json',
      'assets/python_topics/40_python_dictionaries_add.json',
      'assets/python_topics/41_python_dictionaries_remove.json',
      'assets/python_topics/42_python_dictionaries_loop.json',
      'assets/quiz/Quiz_Dictionaries.json', // Placeholder
    ],
    'Conditions & Match': [
      'assets/python_topics/45_python_conditions.json',
      'assets/python_topics/46_python_match.json',
      'assets/python_topics/47_python_match.json',
      'assets/quiz/Quiz_Conditions.json', // Placeholder
    ],
    'Loops': [
      'assets/python_topics/19_python_lists_loop.json',
      'assets/python_topics/48_python_while_loops.json',
      'assets/python_topics/49_python_for_loops.json',
      'assets/quiz/Quiz_Loops.json', // Placeholder
    ],
    'Functions & Lambda': [
      'assets/python_topics/50_python_functions.json',
      'assets/python_topics/51_python_lambda.json',
      'assets/quiz/Quiz_Functions.json', // Placeholder
    ],
    'Classes & OOP': [
      'assets/python_topics/53_python_classes.json',
      'assets/python_topics/54_python_inheritance.json',
      'assets/python_topics/56_python_polymorphism.json',
      'assets/quiz/Quiz_Classes.json', // Placeholder
    ],
    'Strings & Input': [
      'assets/python_topics/11_python_strings.json',
      'assets/python_topics/59_python_user_input.json',
      'assets/quiz/Quiz_Strings.json', // Placeholder
    ],
    'Regular Expressions & JSON': [
      'assets/python_topics/57_python_json.json',
      'assets/python_topics/58_python_regex.json',
      'assets/quiz/Quiz_Regex_JSON.json', // Placeholder
    ],
    'Advanced Python': [
      'assets/python_topics/20_python_lists_comprehension.json',
      'assets/python_topics/43_python_dictionaries_copy.json',
      'assets/python_topics/44_python_dictionaries_nested.json',
      'assets/python_topics/55_python_iterators.json',
      'assets/python_topics/60_python_virtualenv.json',
      'assets/quiz/Quiz_Advanced_Python.json', // Placeholder
    ],
  };

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double padding = screenSize.width * 0.05;

    print("DEBUG: Building Homepage, displayName: $displayName");
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: CustomDrawer(userName: displayName),
      appBar: AppBar(
        backgroundColor:Color(0xff023047),
        elevation: 0,
        toolbarHeight: screenSize.height * 0.25,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Builder(
                      builder: (BuildContext drawerContext) => GestureDetector(
                        onTap: () {
                          print("DEBUG: Menu icon tapped, opening drawer");
                          Scaffold.of(drawerContext).openDrawer();
                        },
                        child: const Icon(Icons.menu, color: Colors.white, size: 30),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      "Hello, $displayName !",
                      style: const TextStyle(
                        fontSize: 22,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Keep learning C++!",
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: 20),
                    Consumer<ProgressProvider>(
                      builder: (context, progressProvider, child) {
                        double progress = progressProvider.globalTotal > 0
                            ? progressProvider.globalProgress / progressProvider.globalTotal
                            : 0.0;
                        print("DEBUG: Global progress: ${(progress * 100).toStringAsFixed(1)}%");
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              backgroundColor: Colors.grey[400],
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              minHeight: 10,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Overall Progress: ${(progress * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Poppins',
                                fontSize: 14,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Image.asset(
                    'assets/7.png',
                    fit: BoxFit.cover,
                    height: 180,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            height: 50,
            color: Color(0xff023047),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: Consumer<ProgressProvider>(
              builder: (context, progressProvider, child) {
                print("DEBUG: Rebuilding GridView with ${courses.length} courses");
                return GridView.builder(
                  padding: EdgeInsets.all(padding),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.9,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: courses.length,
                  itemBuilder: (context, index) {
                    final title = courses[index]['title'];
                    final progress = progressProvider.topicProgress[title] ?? 0.0;
                    return _courseContent(
                      context,
                      icon: courses[index]['icon'],
                      title: title,
                      progress: progress,
                      isOpened: _openedTopics.contains(title),
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


  Widget _courseContent(BuildContext context,
      {required IconData icon, required String title, required double progress, required bool isOpened}) {
    bool isCompleted = progress >= 1.0;
    print("DEBUG: Rendering tile: $title, progress: ${(progress * 100).toStringAsFixed(1)}%, isCompleted: $isCompleted, isOpened: $isOpened");
    return GestureDetector(
      onTap: () {
        _saveOpenedTopic(title);
        print("DEBUG: Navigating to CourseContentScreen, title: $title");
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseContentScreen(
              filenames: topicSubtopicFiles[title] ?? [],
              title: title,
            ),
          ),
        );
      },
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Color(0xffE6ECEF), // Replaced Color(0xffD0F0F5)
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return LinearGradient(
                        colors: [Color(0xff014062), Color(0xff1e679a)], // Replaced Colors.teal.shade400, Colors.teal.shade700
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds);
                    },
                    child: Icon(
                      icon,
                      size: 70,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xff023047),
                      fontFamily: 'Poppins',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    borderRadius: BorderRadius.circular(20),
                    minHeight: 8,
                    backgroundColor: Color(0xffB3C7D1), // Replaced Colors.teal.shade200
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xff023047)), // Replaced Colors.teal.shade600
                  ),
                ),
              ],
            ),
            if (isCompleted)
              Positioned(
                top: 10,
                right: 10,
                child: Icon(
                  Icons.check_circle,
                  color: Color(0xff023047), // Replaced Colors.teal.shade600
                  size: 24,
                ),
              ),
          ],
        ),
      ),
    );
  }
}