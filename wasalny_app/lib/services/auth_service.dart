import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  AuthService() {
    _initUser();
  }

  void _initUser() {
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        await fetchUserData(user.uid);
      } else {
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  Future<void> fetchUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _currentUser = UserModel.fromMap(doc.data()!, doc.id);
      } else {
        // Fallback for first-time or custom login
        final email = _auth.currentUser?.email ?? '';
        final role = (email.toLowerCase() == 'am4303576@gmail.com') ? 'admin' : 'customer';
        _currentUser = UserModel(
          uid: uid,
          email: email,
          name: _auth.currentUser?.displayName ?? 'مستخدم وصلني',
          phone: _auth.currentUser?.phoneNumber ?? '',
          role: role,
          createdAt: DateTime.now(),
        );
        await _firestore.collection('users').doc(uid).set(_currentUser!.toMap());
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  /// Request OTP for login or registration
  Future<bool> requestOtp({
    required String email,
    String? inviteCode,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // In production, calls Firebase Cloud Function: httpsCallable('requestOtp')
      // For immediate offline/standalone fallback or direct verification:
      final normalizedEmail = email.trim().toLowerCase();

      // Check if Admin
      if (normalizedEmail == 'am4303576@gmail.com') {
        // Must match Admin initial code
        if (inviteCode == null || inviteCode.trim() != '178jab90') {
          throw Exception("الرمز السري الخاص بالمالك غير صحيح!");
        }
      }

      // Record OTP request in Firestore
      final otpCode = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
      await _firestore.collection('otp_requests').doc(normalizedEmail).set({
        'email': normalizedEmail,
        'code': otpCode,
        'inviteCode': inviteCode,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': DateTime.now().add(const Duration(minutes: 5)),
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Verify OTP and complete login
  Future<UserModel> verifyOtpAndLogin({
    required String email,
    required String otp,
    String? name,
    String? phone,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final normalizedEmail = email.trim().toLowerCase();
      
      // Verify OTP from Firestore/Cloud Function
      final doc = await _firestore.collection('otp_requests').doc(normalizedEmail).get();
      if (!doc.exists) {
        throw Exception("لم يتم العثور على طلب رمز تأكيد لهذا البريد.");
      }

      final data = doc.data()!;
      final validCode = data['code']?.toString();
      final expiresAt = (data['expiresAt'] as dynamic).toDate();

      if (DateTime.now().isAfter(expiresAt)) {
        throw Exception("انتهت صلاحية رمز التأكيد (5 دقائق). يرجى طلب رمز جديد.");
      }

      if (validCode != otp.trim()) {
        throw Exception("رمز التأكيد المدخل غير صحيح!");
      }

      // Check role determination based on registered restaurant invites or email
      String determinedRole = 'customer';
      String? assignedRestaurantId;

      if (normalizedEmail == 'am4303576@gmail.com') {
        determinedRole = 'admin';
      } else {
        // Check if this email is registered as a manager or staff in restaurants
        final restQuery = await _firestore
            .collection('restaurants')
            .where('managerEmail', isEqualTo: normalizedEmail)
            .limit(1)
            .get();

        if (restQuery.docs.isNotEmpty) {
          determinedRole = 'manager';
          assignedRestaurantId = restQuery.docs.first.id;
        } else {
          // Check staff collection
          final staffQuery = await _firestore
              .collection('staff')
              .where('email', isEqualTo: normalizedEmail)
              .limit(1)
              .get();

          if (staffQuery.docs.isNotEmpty) {
            final staffData = staffQuery.docs.first.data();
            determinedRole = staffData['role'] ?? 'captain';
            assignedRestaurantId = staffData['restaurantId'];
          }
        }
      }

      // Sign in anonymously or custom token
      UserCredential userCred = await _auth.signInAnonymously();
      final uid = userCred.user!.uid;

      _currentUser = UserModel(
        uid: uid,
        email: normalizedEmail,
        name: name ?? (determinedRole == 'admin' ? 'المالك (الأدمن)' : 'مستخدم وصلني'),
        phone: phone ?? '',
        role: determinedRole,
        restaurantId: assignedRestaurantId,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(uid).set(_currentUser!.toMap());
      // Delete used OTP
      await _firestore.collection('otp_requests').doc(normalizedEmail).delete();

      _isLoading = false;
      notifyListeners();
      return _currentUser!;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }
}
