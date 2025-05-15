import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cplus/screens/progressprovider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/bottom_navigation.dart';

class QuizScreen extends StatefulWidget {
  final String courseTitle;
  final List<Map<String, dynamic>> quizData;

  const QuizScreen({
    super.key,
    required this.courseTitle,
    required this.quizData,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestionIndex = 0;
  List<String?> _answers = [];
  bool _quizSubmitted = false;
  bool _showResults = false;
  bool _isLoading = false;
  String _userName = 'User';

  @override
  void initState() {
    super.initState();
    _answers = List.filled(widget.quizData.length, null);
    _fetchUserName();
  }

  Future<void> _fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    print("DEBUG: Fetching username... User: ${user?.uid ?? 'No user'}");

    if (user != null) {
      String? authName = user.displayName;
      print("DEBUG: Firebase Auth displayName: $authName");
      if (authName != null && authName.isNotEmpty && authName.toLowerCase() != 'user') {
        setState(() {
          _userName = authName;
        });
        print("DEBUG: Set userName from Firebase Auth: $_userName");
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
          String fetchedName = data?['displayName'] ?? data?['name'] ?? 'User';
          if (fetchedName.isNotEmpty && fetchedName.toLowerCase() != 'user') {
            setState(() {
              _userName = fetchedName;
            });
            if (user.displayName != fetchedName) {
              await user.updateDisplayName(fetchedName);
              print("DEBUG: Synced Firebase Auth displayName: $fetchedName");
            }
            print("DEBUG: Set userName from Firestore: $_userName");
            return;
          }
        }
      } catch (e) {
        print("DEBUG: Error fetching from Firestore: $e");
      }

      setState(() {
        _userName = 'User';
      });
      print("DEBUG: Set userName to default: $_userName");
    }
  }

  void _nextQuestion() {
    if (_answers[_currentQuestionIndex] != null || _quizSubmitted) {
      if (_currentQuestionIndex < widget.quizData.length - 1) {
        setState(() {
          _currentQuestionIndex++;
        });
      } else if (!_quizSubmitted) {
        _showResult();
      }
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  void _showResult() async {
    if (!mounted || _isLoading) {
      print("DEBUG: Widget unmounted or loading, skipping showResult");
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      setState(() {
        _quizSubmitted = true;
      });
      int score = 0;
      for (int i = 0; i < widget.quizData.length; i++) {
        String? correctAnswerLetter = widget.quizData[i]['correctAnswer']?.toString().toLowerCase();
        String? correctAnswerText;
        if (correctAnswerLetter != null && correctAnswerLetter.isNotEmpty) {
          int optionIndex = correctAnswerLetter.codeUnitAt(0) - 'a'.codeUnitAt(0);
          List<dynamic> options = widget.quizData[i]['options'] ?? [];
          if (optionIndex >= 0 && optionIndex < options.length) {
            correctAnswerText = options[optionIndex]?.toString().trim();
          } else {
            print("DEBUG: Invalid optionIndex $optionIndex for question $i, options: $options");
          }
        } else {
          print("DEBUG: Invalid correctAnswerLetter for question $i: $correctAnswerLetter");
        }
        String? selectedAnswer = _answers[i]?.trim();
        print("DEBUG: Question $i, selected: '$selectedAnswer', correct: '$correctAnswerText'");
        if (selectedAnswer != null && correctAnswerText != null && selectedAnswer == correctAnswerText) {
          score++;
          print("DEBUG: Question $i scored correct");
        } else {
          print("DEBUG: Question $i scored incorrect (selected: '$selectedAnswer', expected: '$correctAnswerText')");
        }
      }
      double scoreFraction = widget.quizData.length > 0 ? score / widget.quizData.length : 0.0;
      print("DEBUG: Quiz score: $score/${widget.quizData.length} ($scoreFraction)");

      await Provider.of<ProgressProvider>(context, listen: false)
          .updateQuizResult(widget.courseTitle, scoreFraction);
      print("DEBUG: Quiz result updated for ${widget.courseTitle}, score: $score/${widget.quizData.length}");

      if (!mounted) {
        print("DEBUG: Widget unmounted after update, skipping dialog");
        return;
      }
      if (score >= 7) {
        await _showSuccessDialog(score);
      } else {
        await _showFailureDialog(score);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showSuccessDialog(int score) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String message = score == widget.quizData.length
            ? 'You aced it! Perfect score—way to go!'
            : 'Nice work! You passed the quiz—keep it up!';
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          backgroundColor: Colors.teal[50],
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
              const SizedBox(width: 10),
              Text(
                'Quiz Completed!',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Your score: $score out of ${widget.quizData.length}',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetQuiz();
              },
              child: Text(
                'Restart Quiz',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Color(0xff023047),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isLoading = true;
                });
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => CustomBottomNavigation(userName: _userName)),
                      (route) => false,
                );
              },
              child: Text(
                'Back to Homepage',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Color(0xff023047),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _currentQuestionIndex = 0;
                  _showResults = true;
                });
              },
              child: const Text(
                'Check Results',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showFailureDialog(int score) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String message = score < 3
            ? 'Don’t worry! Every try counts—review and bounce back!'
            : 'Almost there! A little more practice and you’ll nail it!';
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          backgroundColor: Colors.teal[50],
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cancel, color: Colors.red.shade600, size: 28),
              const SizedBox(width: 10),
              Text(
                'Quiz Failed!',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Your score: $score out of ${widget.quizData.length}',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetQuiz();
              },
              child: const Text(
                'Retake Quiz',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isLoading = true;
                });
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => CustomBottomNavigation(userName: _userName)),
                      (route) => false,
                );
              },
              child: Text(
                'Back to Homepage',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Color(0xff014062),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _currentQuestionIndex = 0;
                  _showResults = true;
                });
              },
              child: const Text(
                'Check Results',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _resetQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _answers = List.filled(widget.quizData.length, null);
      _quizSubmitted = false;
      _showResults = false;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.quizData.isEmpty) {
      return const Scaffold(body: Center(child: Text('No questions available.')));
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final double padding = screenWidth * 0.05;
    final double courseTitleFontSize = (screenWidth * 0.025).clamp(18, 22);
    final double questionNumberFontSize = (screenWidth * 0.02).clamp(14, 16);
    final double questionFontSize = (screenWidth * 0.022).clamp(16, 18);
    final double optionFontSize = (screenWidth * 0.02).clamp(14, 16);

    return Scaffold(
      backgroundColor: Color(0xff023047),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(70),
        child: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Quiz', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Poppins')),
          backgroundColor: Color(0xff023047),
        ),
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.courseTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: courseTitleFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Question ${_currentQuestionIndex + 1} of ${widget.quizData.length}",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: questionNumberFontSize,
                  fontWeight: FontWeight.w600,
                  color: Color(0xffB3C7e8),
                ),
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.quizData.length, (index) {
                    String? correctAnswerLetter = widget.quizData[index]['correctAnswer']?.toString().toLowerCase();
                    String? correctAnswerText;
                    if (correctAnswerLetter != null && correctAnswerLetter.isNotEmpty) {
                      int optionIndex = correctAnswerLetter.codeUnitAt(0) - 'a'.codeUnitAt(0);
                      List<dynamic> options = widget.quizData[index]['options'] ?? [];
                      if (optionIndex >= 0 && optionIndex < options.length) {
                        correctAnswerText = options[optionIndex]?.toString().trim();
                      }
                    }
                    bool isCorrect = _answers[index]?.trim() == correctAnswerText;
                    bool isAnswered = _answers[index] != null && _showResults;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentQuestionIndex = index;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: index == _currentQuestionIndex
                              ? Color(0xff023047)
                              : (isAnswered && _showResults
                              ? (isCorrect ? Colors.green : Colors.red)
                              : Color(0xffE6ECEF)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: index == _currentQuestionIndex || (isAnswered && _showResults) ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xffE6ECEF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.quizData[_currentQuestionIndex]['question'],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: questionFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Column(
                children: List.generate(
                  widget.quizData[_currentQuestionIndex]['options'].length,
                      (index) {
                    String optionText = widget.quizData[_currentQuestionIndex]['options'][index];
                    String? correctAnswerLetter = widget.quizData[_currentQuestionIndex]['correctAnswer']?.toString().toLowerCase();
                    String? correctAnswerText;
                    if (correctAnswerLetter != null && correctAnswerLetter.isNotEmpty) {
                      int optionIndex = correctAnswerLetter.codeUnitAt(0) - 'a'.codeUnitAt(0);
                      List<dynamic> options = widget.quizData[_currentQuestionIndex]['options'] ?? [];
                      if (optionIndex >= 0 && optionIndex < options.length) {
                        correctAnswerText = options[optionIndex]?.toString().trim();
                      }
                    }
                    bool isSelected = _answers[_currentQuestionIndex] == optionText;
                    bool isCorrect = optionText == correctAnswerText;
                    Color borderColor = Colors.black12;
                    double borderWidth = 1.0;
                    if (_showResults) {
                      if (isCorrect) {
                        borderColor = Colors.green;
                        borderWidth = 2.0;
                      } else if (isSelected && !isCorrect) {
                        borderColor = Colors.red;
                        borderWidth = 2.0;
                      }
                    }
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderColor,
                          width: borderWidth,
                        ),
                      ),
                      child: RadioListTile<String>(
                        title: Text(
                          optionText,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: optionFontSize),
                          softWrap: true,
                        ),
                        value: optionText,
                        groupValue: _answers[_currentQuestionIndex],
                        activeColor: Color(0xff014062),
                        onChanged: _quizSubmitted || _isLoading
                            ? null
                            : (value) {
                          setState(() {
                            _answers[_currentQuestionIndex] = value;
                          });
                        },
                        dense: true,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentQuestionIndex > 0)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xff023047),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                        minimumSize: Size(screenWidth * 0.35, 0),
                      ),
                      onPressed: _isLoading ? null : _previousQuestion,
                      child: const Text('Previous', style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
                    )
                  else
                    const SizedBox(width: 0),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showResults
                          ? Color(0xff023047)
                          : (_answers[_currentQuestionIndex] == null && !_quizSubmitted
                          ? Color(0xffE6ECEF)
                          : Color(0xff023047)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      minimumSize: Size(screenWidth * 0.35, 0),
                    ),
                    onPressed: (_isLoading || (_answers[_currentQuestionIndex] == null && !_quizSubmitted))
                        ? null
                        : (_quizSubmitted && _currentQuestionIndex == widget.quizData.length - 1
                        ? () async {
                      setState(() {
                        _isLoading = true;
                      });
                      await Future.delayed(Duration(milliseconds: 500));
                      if (mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => CustomBottomNavigation(userName: _userName)),
                              (route) => false,
                        );
                      }
                    }
                        : (_currentQuestionIndex == widget.quizData.length - 1 && !_quizSubmitted
                        ? _showResult
                        : _nextQuestion)),
                    child: _isLoading
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Text(
                      _quizSubmitted && _currentQuestionIndex == widget.quizData.length - 1
                          ? 'Done'
                          : (_currentQuestionIndex == widget.quizData.length - 1 && !_quizSubmitted
                          ? 'Submit'
                          : 'Next'),
                      style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}