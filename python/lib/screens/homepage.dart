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
    {'icon': Icons.computer_rounded, 'title': 'Introduction to C++'},
    {'icon': Icons.input, 'title': 'Basic Input & Output'},
    {'icon': Icons.assessment, 'title': 'Variables & Constants'},
    {'icon': Icons.category, 'title': 'Data Types'},
    {'icon': Icons.calculate, 'title': 'Operators & Expressions'},
    {'icon': Icons.check_circle, 'title': 'Conditional Statements'},
    {'icon': Icons.loop, 'title': 'Loops & Iterations'},
    {'icon': Icons.repeat_one, 'title': 'Loop Examples'},
    {'icon': Icons.functions, 'title': 'Functions & Methods'},
    {'icon': Icons.stacked_line_chart, 'title': 'Function Overloading'},
    {'icon': Icons.class_, 'title': 'Classes & Objects'},
    {'icon': Icons.construction, 'title': 'Constructors & Inheritance'},
    {'icon': Icons.lock, 'title': 'Polymorphism & Encapsulation'},
    {'icon': Icons.merge, 'title': 'Pointers & References'},
    {'icon': Icons.text_fields, 'title': 'Strings & String Manipulation'},
    {'icon': Icons.grid_view, 'title': 'Array Handling'},
    {'icon': Icons.data_array, 'title': 'Multidimensional Arrays'},
    {'icon': Icons.storage, 'title': 'STL Basics'},
    {'icon': Icons.storage_outlined, 'title': 'STL Advanced'},
    {'icon': Icons.calculate_outlined, 'title': 'C++ Math Essentials'},
    {'icon': Icons.error_outline, 'title': 'Exception Handling'},
    {'icon': Icons.file_copy, 'title': 'File Handling & Streams'},
    {'icon': Icons.library_books, 'title': 'C++ Standard Libraries'},
    {'icon': Icons.book_online, 'title': 'C++ Additional Libraries'},
    {'icon': Icons.label_important, 'title': 'C++ Keywords & Identifiers'},
  ];

  final Map<String, List<String>> topicSubtopicFiles = {
    'Introduction to C++': [
      'assets/cpp_topics/Cpp_Introduction.json',
      'assets/cpp_topics/Cpp_History.json',
      'assets/cpp_topics/Cpp_Syntax.json',
      'assets/cpp_topics/Cpp_Getting_Started.json',
      'assets/quiz/Quiz_Introduction_to_Cpp.json',
    ],
    'Basic Input & Output': [
      'assets/cpp_topics/Cpp_Output_(Print_Text).json',
      'assets/cpp_topics/Cpp_New_Lines.json',
      'assets/cpp_topics/Cpp_Special_Characters.json',
      'assets/cpp_topics/Cpp_User_Input_Strings.json',
      'assets/cpp_topics/Cpp_Comments.json',
      'assets/quiz/Quiz_Basic_Input_&_Output.json'
    ],
    'Variables & Constants': [
      'assets/cpp_topics/Cpp_Variables.json',
      'assets/cpp_topics/Cpp_Declare_Multiple_Variables.json',
      'assets/cpp_topics/Cpp_Variable_Scope.json',
      'assets/cpp_topics/Cpp_Constants.json',
      'assets/quiz/Quiz_Variables_&_Constants.json'
    ],
    'Data Types': [
      'assets/cpp_topics/Cpp_Data_Types.json',
      'assets/cpp_topics/Cpp_Numeric_Data_Types.json',
      'assets/cpp_topics/Cpp_Character_Data_Types.json',
      'assets/cpp_topics/Cpp_Boolean_Data_Types.json',
      'assets/cpp_topics/Cpp_String_Data_Types.json',
      'assets/quiz/Quiz_Data_Types.json'
    ],
    'Operators & Expressions': [
      'assets/cpp_topics/Cpp_Operators.json',
      'assets/cpp_topics/Cpp_Assignment_Operators.json',
      'assets/cpp_topics/Cpp_Comparison_Operators.json',
      'assets/cpp_topics/Cpp_Logical_Operators.json',
      'assets/quiz/Quiz_Operators_&_Expressions.json'
    ],
    'Conditional Statements': [
      'assets/cpp_topics/Cpp_If_..._Else.json',
      'assets/cpp_topics/Cpp_Else_If.json',
      'assets/cpp_topics/Cpp_Switch.json',
      'assets/cpp_topics/Cpp_Short_Hand_If_Else.json',
      'assets/quiz/Quiz_Conditional_Statements.json'
    ],
    'Loops & Iterations': [
      'assets/cpp_topics/Cpp_While_Loop.json',
      'assets/cpp_topics/Cpp_Do_While_Loop.json',
      'assets/cpp_topics/Cpp_For_Loop.json',
      'assets/cpp_topics/Cpp_Nested_Loops.json',
      'assets/quiz/Quiz_Loops_&_Iterations.json'
    ],
    'Loop Examples': [
      'assets/cpp_topics/Cpp_While_Loop_Examples.json',
      'assets/cpp_topics/Cpp_For_Loop_Examples.json',
      'assets/cpp_topics/Cpp_The_foreach_Loop.json',
      'assets/cpp_topics/Cpp_Break_and_Continue.json',
      'assets/quiz/Quiz_Loop_Examples.json'
    ],
    'Functions & Methods': [
      'assets/cpp_topics/Cpp_Functions.json',
      'assets/cpp_topics/Cpp_Function_Examples.json',
      'assets/cpp_topics/Cpp_Function_Parameters.json',
      'assets/cpp_topics/Cpp_Functions_-_Pass_By_Reference.json',
      'assets/quiz/Quiz_Functions_&_Methods.json'
    ],
    'Function Overloading': [
      'assets/cpp_topics/Cpp_Multiple_Parameters.json',
      'assets/cpp_topics/Cpp_Default_Parameters.json',
      'assets/cpp_topics/Cpp_Function_Overloading.json',
      'assets/cpp_topics/Cpp_Recursion.json',
      'assets/quiz/Quiz_Function_Overloading.json'
    ],
    'Classes & Objects': [
      'assets/cpp_topics/Cpp_OOP.json',
      'assets/cpp_topics/Cpp_Classes_and_Objects.json',
      'assets/cpp_topics/Cpp_Class_Methods.json',
      'assets/quiz/Quiz_Classes_&_Objects.json'
    ],
    'Constructors & Inheritance': [
      'assets/cpp_topics/Cpp_Constructors.json',
      'assets/cpp_topics/Cpp_Inheritance.json',
      'assets/cpp_topics/Cpp_Multiple_Inheritance.json',
      'assets/cpp_topics/Cpp_Multilevel_Inheritance.json',
      'assets/quiz/Quiz_Constructors_&_Inheritance.json'
    ],
    'Polymorphism & Encapsulation': [
      'assets/cpp_topics/Cpp_Polymorphism.json',
      'assets/cpp_topics/Cpp_Encapsulation.json',
      'assets/quiz/Quiz_Polymorphism_&_Encapsulation.json'
    ],
    'Pointers & References': [
      'assets/cpp_topics/Cpp_Pointers.json',
      'assets/cpp_topics/Cpp_References.json',
      'assets/cpp_topics/Cpp_Dereference.json',
      'assets/cpp_topics/Cpp_Modify_Pointers.json',
      'assets/cpp_topics/Cpp_Memory_Address.json',
      'assets/quiz/Quiz_Pointers.json'
    ],
    'Strings & String Manipulation': [
      'assets/cpp_topics/Cpp_Strings.json',
      'assets/cpp_topics/Cpp_String_Length.json',
      'assets/cpp_topics/Cpp_String_Concatenation.json',
      'assets/quiz/Quiz_Strings_&_String_Manipulation.json'
    ],
    'Array Handling': [
      'assets/cpp_topics/Cpp_Arrays.json',
      'assets/cpp_topics/Cpp_Arrays_and_Loops.json',
      'assets/cpp_topics/Cpp_Array_Size.json',
      'assets/cpp_topics/Cpp_Omit_Array_Size.json',
      'assets/quiz/Quiz_Arrays.json'
    ],
    'Multidimensional Arrays': [
      'assets/cpp_topics/Cpp_Pass_Array_to_a_Function.json',
      'assets/cpp_topics/Cpp_Multi-Dimensional_Arrays.json',
      'assets/quiz/Quiz_Multidimensional_Arrays.json'
    ],
    'STL Basics': [
      'assets/cpp_topics/Cpp_Data_Structures_and_STL.json',
      'assets/cpp_topics/Cpp_List.json',
      'assets/cpp_topics/Cpp_Deque.json',
      'assets/quiz/Quiz_STL_Basics.json'
    ],
    'STL Advanced': [
      'assets/cpp_topics/Cpp_Stacks.json',
      'assets/cpp_topics/Cpp_Queues.json',
      'assets/cpp_topics/Cpp_Sets.json',
      'assets/cpp_topics/Cpp_Maps.json',
      'assets/cpp_topics/Cpp_Vectors.json',
      'assets/cpp_topics/Cpp_Iterator.json',
      'assets/quiz/Quiz_STL_Advanced.json'
    ],
    'C++ Math Essentials': [
      'assets/cpp_topics/Cpp_Math.json',
      'assets/cpp_topics/Cpp_How_To_Add_Two_Numbers.json',
      'assets/cpp_topics/Cpp_How_To_Generate_Random_Numbers.json',
      'assets/cpp_topics/Cpp_Output_Numbers.json',
      'assets/quiz/Quiz_Cpp_Math_Essentials.json'
    ],
    'Exception Handling': [
      'assets/cpp_topics/Cpp_Exceptions.json',
      'assets/cpp_topics/Cpp_exceptions_more.json'
      'assets/quiz/Quiz_Exception_Handling.json'
    ],
    'File Handling & Streams': [
      'assets/cpp_topics/Cpp_Files.json',
      'assets/cpp_topics/Cpp_fstream_Library_(File_Streams).json',
      'assets/quiz/Quiz_File_Handling.json'
    ],
    'C++ Standard Libraries': [
      'assets/cpp_topics/Cpp_algorithm_Library.json',
      'assets/cpp_topics/Cpp_cmath_Library.json',
      'assets/cpp_topics/Cpp_cstring_Library.json',
      'assets/quiz/Quiz_Cpp_Standard_Libraries.json'
    ],
    'C++ Additional Libraries': [
      'assets/cpp_topics/Cpp_string_Library.json',
      'assets/cpp_topics/Cpp_vector_Library.json',
      'assets/cpp_topics/Cpp_ctime_Library.json',
      'assets/cpp_topics/Cpp_iostream_Library_(Standard_Input___Output_Streams).json',
      'assets/quiz/Quiz_Cpp_Additional_Libraries.json'
    ],
    'C++ Keywords & Identifiers': [
      'assets/cpp_topics/Cpp_Keywords.json',
      'assets/cpp_topics/Cpp_Identifiers.json',
      'assets/cpp_topics/Cpp_Enumeration_(enum).json',
      'assets/quiz/Quiz_Cpp_Keywords_&_Identifiers.json'
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