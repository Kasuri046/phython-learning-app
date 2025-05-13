import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressProvider with ChangeNotifier {
  double _globalProgress = 0.0;
  double _globalTotal = 123.0; // 98 content files + 25 quizzes
  String? _currentUid;
  final Map<String, Set<String>> _readFiles = {};
  final Map<String, bool> _quizPassed = {};
  final Map<String, double> _topicProgress = {};
  final Map<String, bool> _isCompleted = {};

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
    if (user == null) return;

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
    int totalFiles = 5; // Default 4 content + 1 quiz
    if (topic == 'Basic Input & Output' ||
        topic == 'Data Types' ||
        topic == 'STL Advanced' ||
        topic == 'Pointers & References') {
      totalFiles = 6; // 5 content + 1 quiz
    } else if (topic == 'Polymorphism & Encapsulation' ||
        topic == 'Multidimensional Arrays' ||
        topic == 'Exception Handling' ||
        topic == 'File Handling & Streams') {
      totalFiles = 3; // 2 content + 1 quiz
    } else if (topic == 'Classes & Objects' ||
        topic == 'Strings & String Manipulation') {
      totalFiles = 4; // 3 content + 1 quiz
    }
    double progressPerFile = 1.0 / totalFiles;
    double topicProgress = _readFiles[topic]!.length * progressPerFile;
    _topicProgress[topic] = topicProgress.clamp(0.0, 1.0);
    _isCompleted[topic] = topicProgress >= 0.99; // Use local topicProgress

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
    _globalTotal = 123.0;
    _readFiles.clear();
    _quizPassed.clear();
    _topicProgress.clear();
    _isCompleted.clear();
    print("DEBUG: Reset progress (no user): ${_globalProgress.toStringAsFixed(1)}%");
    notifyListeners();
  }
}