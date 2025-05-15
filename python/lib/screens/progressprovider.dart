import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressProvider with ChangeNotifier {
  double _globalProgress = 0.0;
  double _globalTotal = 70.0; // Adjust based on total files
  String? _currentUid;
  final Map<String, Set<String>> _readFiles = {};
  final Map<String, bool> _quizPassed = {};
  final Map<String, double> _topicProgress = {};
  final Map<String, bool> _isCompleted = {};

  // Define topicSubtopicFiles to access accurate file counts
  static const Map<String, List<String>> topicSubtopicFiles = {
    'Python Syntax & Basics': [
      'assets/python_topics/00_python_syntax.json',
      'assets/python_topics/01_python_comments.json',
      'assets/quiz/Quiz_Python_Syntax.json',
    ],
    'Comments & Variables': [
      'assets/python_topics/02_python_variables.json',
      'assets/python_topics/03_python_variables_names.json',
      'assets/python_topics/04_python_variables_multiple.json',
      'assets/python_topics/05_python_variables_output.json',
      'assets/python_topics/06_python_variables_global.json',
      'assets/python_topics/07_python_variables_exercises.json',
      'assets/quiz/Quiz_Variables.json',
    ],
    'Data Types & Casting': [
      'assets/python_topics/08_python_datatypes.json',
      'assets/python_topics/09_python_numbers.json',
      'assets/python_topics/10_python_casting.json',
      'assets/quiz/Quiz_Data_Types.json',
    ],
    'Operators & Booleans': [
      'assets/python_topics/12_python_booleans.json',
      'assets/python_topics/13_python_operators.json',
      'assets/quiz/Quiz_Operators.json',
    ],
    'Lists & Arrays': [
      'assets/python_topics/14_python_lists.json',
      'assets/python_topics/15_python_lists_access.json',
      'assets/python_topics/16_python_lists_change.json',
      'assets/python_topics/17_python_lists_add.json',
      'assets/python_topics/18_python_lists_remove.json',
      'assets/python_topics/52_python_arrays.json',
      'assets/quiz/Quiz_Lists.json',
    ],
    'Tuples': [
      'assets/python_topics/25_python_tuples.json',
      'assets/python_topics/26_python_tuples_access.json',
      'assets/python_topics/27_python_tuples_update.json',
      'assets/python_topics/28_python_tuples_unpack.json',
      'assets/python_topics/30_python_tuples_join.json',
      'assets/quiz/Quiz_Tuples.json',
    ],
    'Sets': [
      'assets/python_topics/31_python_sets.json',
      'assets/python_topics/32_python_sets_access.json',
      'assets/python_topics/33_python_sets_add.json',
      'assets/python_topics/34_python_sets_remove.json',
      'assets/python_topics/35_python_sets_loop.json',
      'assets/python_topics/36_python_sets_join.json',
      'assets/quiz/Quiz_Sets.json',
    ],
    'Dictionaries': [
      'assets/python_topics/37_python_dictionaries.json',
      'assets/python_topics/38_python_dictionaries_access.json',
      'assets/python_topics/39_python_dictionaries_change.json',
      'assets/python_topics/40_python_dictionaries_add.json',
      'assets/python_topics/41_python_dictionaries_remove.json',
      'assets/python_topics/42_python_dictionaries_loop.json',
      'assets/quiz/Quiz_Dictionaries.json',
    ],
    'Conditions & Match': [
      'assets/python_topics/45_python_conditions.json',
      'assets/python_topics/46_python_match.json',
      'assets/python_topics/47_python_match.json',
      'assets/quiz/Quiz_Conditions.json',
    ],
    'Loops': [
      'assets/python_topics/19_python_lists_loop.json',
      'assets/python_topics/48_python_while_loops.json',
      'assets/python_topics/49_python_for_loops.json',
      'assets/quiz/Quiz_Loops.json',
    ],
    'Functions & Lambda': [
      'assets/python_topics/50_python_functions.json',
      'assets/python_topics/51_python_lambda.json',
      'assets/quiz/Quiz_Functions.json',
    ],
    'Classes & OOP': [
      'assets/python_topics/53_python_classes.json',
      'assets/python_topics/54_python_inheritance.json',
      'assets/python_topics/56_python_polymorphism.json',
      'assets/quiz/Quiz_Classes.json',
    ],
    'Strings & Input': [
      'assets/python_topics/11_python_strings.json',
      'assets/python_topics/59_python_user_input.json',
      'assets/quiz/Quiz_Strings.json',
    ],
    'Expressions & JSON': [
      'assets/python_topics/57_python_json.json',
      'assets/python_topics/58_python_regex.json',
      'assets/quiz/Quiz_Regex_JSON.json',
    ],
    'Advanced Python': [
      'assets/python_topics/20_python_lists_comprehension.json',
      'assets/python_topics/43_python_dictionaries_copy.json',
      'assets/python_topics/44_python_dictionaries_nested.json',
      'assets/python_topics/55_python_iterators.json',
      'assets/python_topics/60_python_virtualenv.json',
      'assets/quiz/Quiz_Advanced_Python.json',
    ],
  };

  double get globalProgress => _globalProgress;
  double get globalTotal => _globalTotal;
  Map<String, double> get topicProgress => _topicProgress;
  Map<String, bool> get isCompleted => _isCompleted;

  ProgressProvider() {
    _listenToAuthChanges();
    print("DEBUG: ProgressProvider initialized");
  }

  void _listenToAuthChanges() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _currentUid = user.uid;
        _loadProgress(user.uid);
        print("DEBUG: User logged in, UID: $_currentUid");
      } else {
        _currentUid = null;
        _resetProgress();
        print("DEBUG: No user logged in, progress reset");
      }
    });
  }

  Future<void> markFileRead(String filePath, String topic) async {
    if (_currentUid == null) {
      print("DEBUG: No user logged in, skipping markFileRead");
      return;
    }
    _readFiles[topic] ??= {};
    if (_readFiles[topic]!.contains(filePath)) {
      print("DEBUG: File already read: $filePath");
      return;
    }
    _readFiles[topic]!.add(filePath);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .collection('progress')
          .doc(topic)
          .set({
        'readFiles': _readFiles[topic]!.toList(),
        'progress': _topicProgress[topic] ?? 0.0,
        'isCompleted': _isCompleted[topic] ?? false,
      }, SetOptions(merge: true));
      _updateTopicProgress(topic);
      await _recalculateProgress();
      print("DEBUG: Marked file read: $filePath, topic: $topic, progress: ${_topicProgress[topic]! * 100}%");
      notifyListeners();
    } catch (e) {
      print("DEBUG: Error saving file to Firestore: $e");
    }
  }

  Future<void> updateQuizResult(String topic, double score) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("DEBUG: No user logged in, skipping updateQuizResult");
      return;
    }

    final topicDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('quizzes')
        .doc(topic);

    final snapshot = await topicDoc.get();
    bool existingQuizPassed = snapshot.exists && (snapshot.data()?['quizPassed'] ?? false);
    bool newQuizPassed = score >= 0.7;

    if (!existingQuizPassed || newQuizPassed) {
      _quizPassed[topic] = newQuizPassed;
      if (newQuizPassed) {
        String quizFile = 'assets/quiz/Quiz_${topic.replaceAll(' ', '_')}.json';
        await markFileRead(quizFile, topic);
      }
      await topicDoc.set({
        'score': score,
        'quizPassed': newQuizPassed,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _updateTopicProgress(topic);
      // Explicitly check if all files are read and quiz is passed
      if (newQuizPassed && topicSubtopicFiles[topic] != null) {
        bool allFilesRead = topicSubtopicFiles[topic]!.every((file) => _readFiles[topic]?.contains(file) ?? false);
        if (allFilesRead) {
          _isCompleted[topic] = true;
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUid)
              .collection('progress')
              .doc(topic)
              .set({'isCompleted': true}, SetOptions(merge: true));
          print("DEBUG: Marked topic $topic as completed (all files read and quiz passed)");
        }
      }
      await _recalculateProgress();

      print('DEBUG: Quiz result for $topic: score=$score, passed=$newQuizPassed, topic progress: ${_topicProgress[topic]! * 100}%');
      print('DEBUG: Recalculated global progress: ${_globalProgress.toStringAsFixed(1)}%');
      notifyListeners();
    } else {
      print('DEBUG: Skipped quiz update for $topic: already passed, score=$score');
    }
  }

  bool isFileRead(String topic, String file) {
    return _readFiles[topic]?.contains(file) ?? false;
  }

  void _updateTopicProgress(String topic) {
    _readFiles[topic] ??= {};
    // Use topicSubtopicFiles for accurate total file count
    int totalFiles = topicSubtopicFiles[topic]?.length ?? 5; // Fallback to 5 if topic not found
    double progressPerFile = 1.0 / totalFiles;
    double topicProgress = _readFiles[topic]!.length * progressPerFile;
    _topicProgress[topic] = topicProgress.clamp(0.0, 1.0);
    // Check if all files are read (including quiz)
    _isCompleted[topic] = _readFiles[topic]!.length >= totalFiles && (_quizPassed[topic] ?? false);

    if (_currentUid != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .collection('progress')
          .doc(topic)
          .set({
        'progress': _topicProgress[topic],
        'isCompleted': _isCompleted[topic],
      }, SetOptions(merge: true));
    }

    print("DEBUG: Updated topic progress: $topic, ${_topicProgress[topic]! * 100}% (readFiles: ${_readFiles[topic]!.length}/$totalFiles)");
  }

  Future<void> _recalculateProgress() async {
    double totalFilesRead = 0.0;
    for (var topic in _readFiles.keys) {
      totalFilesRead += _readFiles[topic]!.length;
    }
    _globalProgress = (totalFilesRead / _globalTotal) * 100;

    if (_currentUid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .set({'progress': _globalProgress / 100}, SetOptions(merge: true));
    }

    print("DEBUG: Recalculated global progress: ${_globalProgress.toStringAsFixed(1)}% (totalFilesRead: $totalFilesRead/$_globalTotal)");
    notifyListeners();
  }

  Future<void> _loadProgress(String uid) async {
    try {
      QuerySnapshot progressDocs = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('progress')
          .get();
      _readFiles.clear();
      _topicProgress.clear();
      _isCompleted.clear();
      for (var doc in progressDocs.docs) {
        String topic = doc.id;
        var data = doc.data() as Map<String, dynamic>;
        _readFiles[topic] = List<String>.from(data['readFiles'] ?? []).toSet();
        _topicProgress[topic] = (data['progress'] ?? 0.0).toDouble();
        _isCompleted[topic] = data['isCompleted'] ?? false;
      }
      QuerySnapshot quizDocs = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('quizzes')
          .get();
      _quizPassed.clear();
      for (var doc in quizDocs.docs) {
        _quizPassed[doc.id] = doc['quizPassed'] ?? false;
      }
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      _globalProgress = (userDoc.data()?['progress'] ?? 0.0).toDouble() * 100;

      for (var topic in _readFiles.keys) {
        _updateTopicProgress(topic);
      }
      await _recalculateProgress();
      print("DEBUG: Loaded progress for $uid: ${_globalProgress.toStringAsFixed(1)}%, files: ${_readFiles.length}, quizzes: ${_quizPassed.length}");
      notifyListeners();
    } catch (e) {
      print("DEBUG: Error loading Firestore: $e");
      _globalProgress = 0.0;
      _topicProgress.clear();
      _readFiles.clear();
      _quizPassed.clear();
      _isCompleted.clear();
      notifyListeners();
    }
  }

  Future<void> resetProgress() async {
    if (_currentUid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUid)
            .collection('progress')
            .get()
            .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.delete();
          }
        });
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUid)
            .collection('quizzes')
            .get()
            .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.delete();
          }
        });
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUid)
            .set({'progress': 0.0}, SetOptions(merge: true));
      } catch (e) {
        print("DEBUG: Error clearing Firestore: $e");
      }
      _globalProgress = 0.0;
      _readFiles.clear();
      _quizPassed.clear();
      _topicProgress.clear();
      _isCompleted.clear();
      print("DEBUG: Reset progress for $_currentUid: ${_globalProgress.toStringAsFixed(1)}%");
      notifyListeners();
    } else {
      _resetProgress();
    }
  }

  void _resetProgress() {
    _globalProgress = 0.0;
    _globalTotal = 123.0; // Adjust if needed
    _readFiles.clear();
    _quizPassed.clear();
    _topicProgress.clear();
    _isCompleted.clear();
    print("DEBUG: Reset progress (no user): ${_globalProgress.toStringAsFixed(1)}%");
    notifyListeners();
  }
}