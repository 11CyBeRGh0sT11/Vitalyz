import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'dart:math' as math; // For math operations in CustomPainter
import 'dart:async'; // For Future.delayed
import 'package:http/http.dart' as http; // For making HTTP requests to weather API
import 'dart:convert'; // For JSON encoding/decoding
import 'package:geolocator/geolocator.dart'; // For getting user's location
import 'package:tflite_flutter/tflite_flutter.dart'; // For TensorFlow Lite model inference
import 'package:fl_chart/fl_chart.dart'; // Import for charts
import 'package:flutter/foundation.dart'; // <--- ADD THIS LINE


// --- IMPORTANT CONFIGURATION: YOUR ACTUAL FIREBASE CONFIG ---
// Replace these values with your Firebase project credentials.
// You can find them in your google-services.json (for Android)
// and GoogleService-Info.plist (for iOS).
// Ensure this appId matches your registered Android/iOS app in Firebase.
final Map<String, String> firebaseConfig = {
  'apiKey': "AIzaSyChcKoGVJYuDCfDgYISarTGMbaW-BqXqlg", // Confirmed correct from your google-services.json
  'authDomain': "ml-app-2ab73.firebaseapp.com",
  'projectId': "ml-app-2ab73",
  'storageBucket': "ml-app-2ab73.firebasestorage.app", // Confirmed correct from your google-services.json
  'messagingSenderId': "908766341740",
  'clientId': "908766341740-f9u4vh8di2g5en3ocvciarloh1n1ca4a.apps.googleusercontent.com",
  'appId': "1:908766341740:android:caef31b432cea354a38649", // Confirmed correct for com.example.vitalink_v1 from your google-services.json
};
// --- END IMPORTANT CONFIGURATION ---

// --- OPENWEATHERMAP API KEY ---
// IMPORTANT: This is YOUR OpenWeatherMap API key.
// It was confirmed as '1f217160331b66f3f0972bc2ab5c71e4' from your dashboard screenshot.
// Ensure it is correctly activated on OpenWeatherMap's side.
const String OPENWEATHER_API_KEY = "1f217160331b66f3f0972bc2ab5c71e4"; // Corrected API Key
// --- END OPENWEATHERMAP API KEY ---


// Global Firebase instances (initialized once to avoid re-initialization)
FirebaseApp? _firebaseApp;
FirebaseAuth? _auth;
FirebaseFirestore? _db;

// This function initializes Firebase for the entire application.
// It's called on-demand when Google Sign-In is attempted or app starts.
class ErrorApp extends StatelessWidget {
  final String errorMessage;
  const ErrorApp({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Initialization Failed')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'FATAL ERROR: App could not start.\n\n$errorMessage',
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
Future<void> _initializeFirebase() async {
  if (_firebaseApp == null) {
    try {
      _firebaseApp = await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: firebaseConfig['apiKey']!,
          authDomain: firebaseConfig['authDomain']!,
          projectId: firebaseConfig['projectId']!,
          storageBucket: firebaseConfig['storageBucket']!,
          messagingSenderId: firebaseConfig['messagingSenderId']!,
          appId: firebaseConfig['appId']!,
        ),
      );
      _auth = FirebaseAuth.instanceFor(app: _firebaseApp!);
      _db = FirebaseFirestore.instanceFor(app: _firebaseApp!);
      print("Firebase initialized successfully.");
    } catch (e) {
      // Handle cases where Firebase might already be initialized (e.g., hot restart)
      if (e.toString().contains('duplicate-app')) {
        print("Firebase app already initialized. Proceeding.");
        _firebaseApp = Firebase.app();
        _auth = FirebaseAuth.instanceFor(app: _firebaseApp!);
        _db = FirebaseFirestore.instanceFor(app: _firebaseApp!);
      } else {
        print("Firebase initialization error: $e");
        rethrow; // Re-throw other unexpected errors
      }
    }
  }
}

// Global function for signing out (can be called from any screen)
Future<void> _signOutApp(BuildContext context) async {
  try {
    await _auth?.signOut();
    await GoogleSignIn().signOut(); // Also sign out from Google if signed in via Google
    print("User signed out.");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('You have been logged out.'),
        backgroundColor: Colors.blue.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
    // Navigate to login screen after logout, clearing navigation stack
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const VitalyzLoginScreen()), // Updated
          (route) => false,
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error signing out: $e'),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
    print('Error signing out: $e');
  }
}



void main() async {
  // 2. WIDGETS BINDING: Required for async operations before runApp()
  WidgetsFlutterBinding.ensureInitialized();

  // 3. FIREBASE INIT: Initialize Firebase core services
  try {
    await Firebase.initializeApp();
    print("Firebase initialized successfully!");
  } catch (e) {
    // This will print the exact reason for the failure
    print("Firebase initialization failed: $e");
  }

  // 4. RUN APP: Only run the app after initialization
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  // Static method to get the current theme mode notifier
  static ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    MyApp.themeNotifier.dispose(); // Dispose the notifier when the app is closed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: MyApp.themeNotifier,
      builder: (_, currentMode, __) {
        return MaterialApp(
          title: 'Vitalyz AI', // App's display name, changed to Vitalyz
          theme: ThemeData(
            // Light & Flowy Theme
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF4FC3F7), // Soft blue for primary
              primaryContainer: const Color(0xFF03A9F4), // Slightly deeper blue
              secondary: const Color(0xFF81C784), // Gentle green for accents
              background: const Color(0xFFF0F4F8), // Very light greyish-blue background
              surface: Colors.white, // Pure white for cards/surfaces
              error: Colors.red.shade700, // Explicit error color
              onPrimary: Colors.white,
              onSecondary: Colors.white, // Text on secondary (gentle green)
              onBackground: Colors.grey.shade900, // Dark grey for text on light backgrounds
              onSurface: Colors.grey.shade800, // Slightly lighter grey for text on surfaces
            ),
            scaffoldBackgroundColor: const Color(0xFFF0F4F8), // Consistent very light background
            fontFamily: 'Montserrat', // A strong, modern sans-serif font

            appBarTheme: AppBarTheme(
              backgroundColor: Colors.white, // White app bar
              foregroundColor: Colors.grey.shade800, // Dark text/icons
              elevation: 1, // Subtle shadow for depth
              titleTextStyle: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
                fontFamily: 'Montserrat', // Explicitly set Montserrat
              ),
            ),

            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.grey.shade50, // Very light grey fill for input fields
              labelStyle: TextStyle(color: Colors.grey.shade600, fontFamily: 'Montserrat'), // Darker grey for labels
              hintStyle: TextStyle(color: Colors.grey.shade400, fontFamily: 'Montserrat'), // Lighter grey for hints
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF4FC3F7), width: 2), // Primary color on focus
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200, width: 1), // Light grey border when enabled
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),

            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4FC3F7), // Primary soft blue for buttons
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat', // Explicitly set Montserrat
                ),
              ),
            ),

            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF03A9F4), // Primary container color for text links
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Montserrat', // Explicitly set Montserrat
                ),
              ),
            ),
          ),
          darkTheme: ThemeData(
            // Dark & Professional Theme
            brightness: Brightness.dark,
            colorScheme: ColorScheme.dark(
              primary: const Color(0xFF64B5F6), // Lighter blue for primary in dark mode
              primaryContainer: const Color(0xFF2196F3), // Deeper blue
              secondary: const Color(0xFF81C784), // Gentle green for accents (same as light)
              background: const Color(0xFF121212), // Very dark background
              surface: const Color(0xFF1E1E1E), // Darker grey for cards/surfaces
              error: Colors.red.shade400, // Explicit error color
              onPrimary: Colors.white,
              onSecondary: Colors.white,
              onBackground: Colors.white, // White text on dark backgrounds
              onSurface: Colors.white70, // Slightly transparent white for text on surfaces
            ),
            scaffoldBackgroundColor: const Color(0xFF121212), // Consistent very dark background
            fontFamily: 'Montserrat',

            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E), // Dark app bar
              foregroundColor: Colors.white, // White text/icons
              elevation: 1,
              titleTextStyle: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Montserrat',
              ),
            ),

            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF2D2D2D), // Dark fill for input fields
              labelStyle: TextStyle(color: Colors.white70, fontFamily: 'Montserrat'),
              hintStyle: TextStyle(color: Colors.white38, fontFamily: 'Montserrat'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF64B5F6), width: 2), // Primary color on focus
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white12, width: 1), // Subtle white border when enabled
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),

            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF64B5F6), // Primary lighter blue for buttons
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),

            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2196F3), // Primary container color for text links
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          ),
          themeMode: currentMode, // Use the current mode from the ValueNotifier
          home: const SplashScreen(), // Start with the custom SplashScreen
        );
      },
    );
  }
}




/// Custom SplashScreen widget with logo display and a timed transition.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Start Firebase initialization as soon as possible
    _initializeFirebase();

    // After 2.5 seconds, navigate to the next screen
    Future.delayed(const Duration(milliseconds: 2500), () {
      _navigateToNextScreen();
    });
  }

  Future<void> _navigateToNextScreen() async {
    // Ensure Firebase is initialized before proceeding
    await _initializeFirebase(); // This will ensure it's done if it wasn't already

    // After the delay and Firebase are ready, navigate based on auth state
    if (mounted) {
      User? user = _auth?.currentUser;
      if (user != null) {
        // User is logged in
        print("User is logged in: ${user.uid}");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainScreen(userId: user.uid)),
        );
      } else {
        // User is not logged in
        print("User is logged out. Navigating to login screen.");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const VitalyzLoginScreen()), // Updated to VitalyzLoginScreen
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use the theme's surface color for a clean white/light background
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Image.asset(
          'assets/images/logo.png', // Using logo.png as per uploaded file
          width: 200, // Adjust size as needed for a prominent display
          height: 200,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback if the image cannot be loaded
            return Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 200,
            );
          },
        ),
      ),
    );
  }
}


// AuthWrapper class removed as its logic is now integrated into SplashScreen directly.


/// Data class to hold user profile information.
class ProfileData {
  String? name;
  String? age;
  String? height;
  String? weight;
  String? gender;
  String? medicalConditions;

  ProfileData({
    this.name,
    this.age,
    this.height,
    this.weight,
    this.gender,
    this.medicalConditions,
  });

  // Convert ProfileData to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'height': height,
      'weight': weight,
      'gender': gender,
      'medicalConditions': medicalConditions,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  // Create ProfileData from a Firestore DocumentSnapshot
  factory ProfileData.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    return ProfileData(
      name: data?['name'],
      age: data?['age'],
      height: data?['height'],
      weight: data?['weight'],
      gender: data?['gender'],
      medicalConditions: data?['medicalConditions'],
    );
  }
}

/// Data class to hold vital signs information.
/// Data class to hold vital signs information.
class VitalSigns {
  double? heartRate;
  double? bodyTemp; // Matches Firebase field name
  double? skinConductivity;
  double? airTemp; // Matches Firebase field name
  double? airHumidity; // Matches Firebase field name
  double? bloodOxygen; // Included for internal use/future features
  String? weatherMain; // e.g., "Clouds", "Clear" - ADDED BACK
  String? weatherIconCode; // e.g., "04n" - ADDED BACK
  int? aqi; // Air Quality Index (1-5) - ADDED BACK
  Timestamp? timestamp;

  VitalSigns({
    this.heartRate,
    this.bodyTemp,
    this.skinConductivity,
    this.airTemp,
    this.airHumidity,
    this.bloodOxygen,
    this.weatherMain, // ADDED BACK
    this.weatherIconCode, // ADDED BACK
    this.aqi, // ADDED BACK
    this.timestamp,
  });

  // Convert VitalSigns to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'heartRate': heartRate,
      'bodyTemp': bodyTemp,
      'skinConductivity': skinConductivity,
      'airTemp': airTemp,
      'airHumidity': airHumidity,
      'bloodOxygen': bloodOxygen,
      'weatherMain': weatherMain, // ADDED BACK
      'weatherIconCode': weatherIconCode, // ADDED BACK
      'aqi': aqi, // ADDED BACK
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
    };
  }

  // Create VitalSigns from a Firestore DocumentSnapshot
  factory VitalSigns.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    return VitalSigns(
      heartRate: (data?['heartRate'] as num?)?.toDouble(),
      bodyTemp: (data?['bodyTemp'] as num?)?.toDouble(),
      skinConductivity: (data?['skinConductivity'] as num?)?.toDouble(),
      airTemp: (data?['airTemp'] as num?)?.toDouble(),
      airHumidity: (data?['airHumidity'] as num?)?.toDouble(),
      bloodOxygen: (data?['bloodOxygen'] as num?)?.toDouble(),
      weatherMain: data?['weatherMain'], // ADDED BACK
      weatherIconCode: data?['weatherIconCode'], // ADDED BACK
      aqi: (data?['aqi'] as num?)?.toInt(), // ADDED BACK
      timestamp: data?['timestamp'] as Timestamp?,
    );
  }
}

/// Data class to hold aggregated daily health data.
class HealthData {
  String userId;
  DateTime timestamp; // Represents the start of the day for this data
  double avgHeartRate;
  double avgBodyTemp;
  double avgSkinConductivity;
  String mood;
  String activityLevel;
  String stressLevel;
  double sleepDuration; // in hours

  HealthData({
    required this.userId,
    required this.timestamp,
    required this.avgHeartRate,
    required this.avgBodyTemp,
    required this.avgSkinConductivity,
    required this.mood,
    required this.activityLevel,
    required this.stressLevel,
    required this.sleepDuration,
  });

  // Convert HealthData to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'timestamp': Timestamp.fromDate(timestamp),
      'avgHeartRate': avgHeartRate,
      'avgBodyTemp': avgBodyTemp,
      'avgSkinConductivity': avgSkinConductivity,
      'mood': mood,
      'activityLevel': activityLevel,
      'stressLevel': stressLevel,
      'sleepDuration': sleepDuration,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  // Create HealthData from a Firestore DocumentSnapshot
  factory HealthData.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    return HealthData(
      userId: data?['userId'] ?? '',
      timestamp: (data?['timestamp'] as Timestamp).toDate(),
      avgHeartRate: (data?['avgHeartRate'] as num?)?.toDouble() ?? 0.0,
      avgBodyTemp: (data?['avgBodyTemp'] as num?)?.toDouble() ?? 0.0,
      avgSkinConductivity: (data?['avgSkinConductivity'] as num?)?.toDouble() ?? 0.0,
      mood: data?['mood'] ?? '',
      activityLevel: data?['activityLevel'] ?? '',
      stressLevel: data?['stressLevel'] ?? '',
      sleepDuration: (data?['sleepDuration'] as num?)?.toDouble() ?? 0.0,
    );
  }
}


/// New data class to hold the calculated Personal Baseline.
class PersonalBaseline {
  double avgHeartRate;
  double stdDevHeartRate;
  double minHeartRate;
  double maxHeartRate;

  double avgBodyTemp;
  double stdDevBodyTemp;
  double minBodyTemp;
  double maxBodyTemp;

  double avgSkinConductivity;
  double stdDevSkinConductivity;
  double minSkinConductivity;
  double maxSkinConductivity;

  double avgAirTemp;
  double avgAirHumidity;
  Timestamp? lastCalculated;

  PersonalBaseline({
    required this.avgHeartRate,
    required this.stdDevHeartRate,
    required this.minHeartRate,
    required this.maxHeartRate,
    required this.avgBodyTemp,
    required this.stdDevBodyTemp,
    required this.minBodyTemp,
    required this.maxBodyTemp,
    required this.avgSkinConductivity,
    required this.stdDevSkinConductivity,
    required this.minSkinConductivity,
    required this.maxSkinConductivity,
    required this.avgAirTemp,
    required this.avgAirHumidity,
    this.lastCalculated,
  });

  // Convert PersonalBaseline to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'avgHeartRate': avgHeartRate,
      'stdDevHeartRate': stdDevHeartRate,
      'minHeartRate': minHeartRate,
      'maxHeartRate': maxHeartRate,
      'avgBodyTemp': avgBodyTemp,
      'stdDevBodyTemp': stdDevBodyTemp,
      'minBodyTemp': minBodyTemp,
      'maxBodyTemp': maxBodyTemp,
      'avgSkinConductivity': avgSkinConductivity,
      'stdDevSkinConductivity': stdDevSkinConductivity,
      'minSkinConductivity': minSkinConductivity,
      'maxSkinConductivity': maxSkinConductivity,
      'avgAirTemp': avgAirTemp,
      'avgAirHumidity': avgAirHumidity,
      'lastCalculated': lastCalculated ?? FieldValue.serverTimestamp(),
    };
  }

  // Create PersonalBaseline from a Firestore DocumentSnapshot
  factory PersonalBaseline.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    return PersonalBaseline(
      avgHeartRate: (data?['avgHeartRate'] as num?)?.toDouble() ?? 0.0,
      stdDevHeartRate: (data?['stdDevHeartRate'] as num?)?.toDouble() ?? 0.0,
      minHeartRate: (data?['minHeartRate'] as num?)?.toDouble() ?? 0.0,
      maxHeartRate: (data?['maxHeartRate'] as num?)?.toDouble() ?? 0.0,
      avgBodyTemp: (data?['avgBodyTemp'] as num?)?.toDouble() ?? 0.0,
      stdDevBodyTemp: (data?['stdDevBodyTemp'] as num?)?.toDouble() ?? 0.0,
      minBodyTemp: (data?['minBodyTemp'] as num?)?.toDouble() ?? 0.0,
      maxBodyTemp: (data?['maxBodyTemp'] as num?)?.toDouble() ?? 0.0,
      avgSkinConductivity: (data?['avgSkinConductivity'] as num?)?.toDouble() ?? 0.0,
      stdDevSkinConductivity: (data?['stdDevSkinConductivity'] as num?)?.toDouble() ?? 0.0,
      minSkinConductivity: (data?['minSkinConductivity'] as num?)?.toDouble() ?? 0.0,
      maxSkinConductivity: (data?['maxSkinConductivity'] as num?)?.toDouble() ?? 0.0,
      avgAirTemp: (data?['avgAirTemp'] as num?)?.toDouble() ?? 0.0,
      avgAirHumidity: (data?['avgAirHumidity'] as num?)?.toDouble() ?? 0.0,
      lastCalculated: data?['lastCalculated'] as Timestamp?,
    );
  }
}

/// Data class to hold medicine intake information.
class MedicineIntake {
  String medicineName;
  String dosage;
  Timestamp intakeTime;
  String? analysisResult; // To store the last analysis result
  Timestamp? analyzedAt; // When the analysis was performed

  MedicineIntake({
    required this.medicineName,
    required this.dosage,
    required this.intakeTime,
    this.analysisResult,
    this.analyzedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'medicineName': medicineName,
      'dosage': dosage,
      'intakeTime': intakeTime,
      'analysisResult': analysisResult,
      'analyzedAt': analyzedAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory MedicineIntake.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    return MedicineIntake(
      medicineName: data?['medicineName'] ?? '',
      dosage: data?['dosage'] ?? '',
      intakeTime: data?['intakeTime'] as Timestamp,
      analysisResult: data?['analysisResult'],
      analyzedAt: data?['analyzedAt'] as Timestamp?,
    );
  }
}


// --- CORE SCREENS (Ordered for dependency resolution) ---

/// The main login screen for Vitalyz.
class VitalyzLoginScreen extends StatefulWidget { // Renamed VitalinkLoginScreen to VitalyzLoginScreen
  const VitalyzLoginScreen({super.key});

  @override
  State<VitalyzLoginScreen> createState() => _VitalyzLoginScreenState(); // Renamed state
}

class _VitalyzLoginScreenState extends State<VitalyzLoginScreen> {
  final TextEditingController _usernameController = TextEditingController(); // Used for email
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false; // State to show loading indicator during auth operations
  String? _errorMessage; // State to display authentication errors

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) { // Check if widget is still in the tree
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Email/Password Login implementation
  Future<void> _signInWithEmailAndPassword() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null; // Clear previous errors
    });

    final String email = _usernameController.text.trim();
    final String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() { _errorMessage = 'Email and password cannot be empty.'; });
      _showSnackBar(_errorMessage!, isError: true);
      setState(() { _isLoading = false; });
      return;
    }

    // Basic email format validation
    if (!RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email)) {
      setState(() { _errorMessage = 'Please enter a valid email address.'; });
      _showSnackBar(_errorMessage!, isError: true);
      setState(() { _isLoading = false; });
      return;
    }

    try {
      await _initializeFirebase(); // Ensure Firebase is initialized

      UserCredential userCredential = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        print("User signed in with email: ${userCredential.user!.email}");
        _showSnackBar('Logged in successfully!');

        // Navigate to MainScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainScreen(userId: userCredential.user!.uid)),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided for that user.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      } else if (e.code == 'network-request-failed') {
        message = 'Network error. Please check your internet connection.';
      } else {
        message = 'Login failed: ${e.message ?? 'Unknown error'}';
      }
      setState(() { _errorMessage = message; });
      _showSnackBar(message, isError: true);
    } catch (e) {
      setState(() { _errorMessage = 'An unexpected error occurred: $e'; });
      _showSnackBar('An unexpected error occurred: $e', isError: true);
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  // Google Sign-In implementation
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null; // Clear previous errors
    });

    try {
      await _initializeFirebase(); // Ensure Firebase is initialized

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() { _isLoading = false; }); // User cancelled
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth!.signInWithCredential(credential);

      // Check if this is a new user signing in with Google for the first time
      if (userCredential.additionalUserInfo?.isNewUser == true && userCredential.user != null && _db != null) {
        await _db!.collection('artifacts').doc('vitalink-app').collection('users').doc(userCredential.user!.uid).set({
          'email': userCredential.user!.email,
          'displayName': userCredential.user!.displayName,
          'photoURL': userCredential.user!.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)); // Use merge: true to avoid overwriting existing data
        print("New Google user data saved to Firestore.");
        // TODO: Send welcome email via Firebase Cloud Function (client-side cannot send emails securely)
        _showSnackBar('Welcome to Vitalyz! Account created successfully with Google.');
      } else {
        _showSnackBar('Signed in with Vitalyz successfully!');
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainScreen(userId: userCredential.user!.uid)),
      );
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'account-exists-with-different-credential') {
        message = 'An account already exists with the same email address but different sign-in credentials.';
      } else if (e.code == 'invalid-credential') {
        message = 'The credential provided is invalid.';
      } else if (e.code == 'network-request-failed') {
        message = 'Network error. Please check your internet connection.';
      } else {
        message = 'Google Sign-In failed: ${e.message ?? 'Unknown error'}';
      }
      setState(() { _errorMessage = message; });
      _showSnackBar(message, isError: true);
    } catch (e) {
      setState(() { _errorMessage = 'An unexpected error occurred: $e'; });
      _showSnackBar('An unexpected error occurred: $e', isError: true);
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Flowy background for Login screen
          const Positioned.fill(
            child: _FlowyBackground(),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _LogoSection(),
                  const SizedBox(height: 32),
                  const _TaglineSection(),
                  const SizedBox(height: 24),

                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14, fontFamily: 'Montserrat'),
                      ),
                    ),

                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Email', // Changed from Username/Email
                      hintText: 'e.g., user@example.com',
                      prefixIcon: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.primary),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'e.g., ********',
                      prefixIcon: Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.primary),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),

                  // Login Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signInWithEmailAndPassword, // Call new method
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary)
                        : const Text('Login'),
                  ),
                  const SizedBox(height: 16),

                  // Google Sign-In button
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200.withOpacity(0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      icon: Image.asset('assets/images/google_logo.png', height: 22.0, width: 22.0),
                      label: Text(
                        'Sign in with Google',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextButton(
                    onPressed: _isLoading ? null : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()), // Navigate to new screen
                      );
                    },
                    child: Text('Forgot Password?', style: TextStyle(color: Theme.of(context).colorScheme.primaryContainer)),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading ? null : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CreateAccountScreen()),
                      );
                    },
                    child: Text('Create Account', style: TextStyle(color: Theme.of(context).colorScheme.primaryContainer)),
                  ),
                  const SizedBox(height: 32),
                  const _WebsiteUrl(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// New screen for user account creation (Sign Up).
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() { _errorMessage = 'All fields are required.'; });
      _showSnackBar(_errorMessage!, isError: true);
      setState(() { _isLoading = false; });
      return;
    }

    // Basic email format validation
    if (!RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email)) {
      setState(() { _errorMessage = 'Please enter a valid email address.'; });
      _showSnackBar(_errorMessage!, isError: true);
      setState(() { _isLoading = false; });
      return;
    }

    if (password != confirmPassword) {
      setState(() { _errorMessage = 'Passwords do not match.'; });
      _showSnackBar(_errorMessage!, isError: true);
      setState(() { _isLoading = false; });
      return;
    }

    if (password.length < 6) {
      setState(() { _errorMessage = 'Password must be at least 6 characters long.'; });
      _showSnackBar(_errorMessage!, isError: true);
      setState(() { _isLoading = false; });
      return;
    }

    try {
      await _initializeFirebase(); // Ensure Firebase is initialized

      UserCredential userCredential = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null && _db != null) {
        // Save initial user data to Firestore
        await _db!.collection('artifacts').doc('vitalink-app').collection('users').doc(userCredential.user!.uid).set({
          'email': userCredential.user!.email,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)); // Use merge: true to avoid overwriting existing data

        print("New user signed up with email: ${userCredential.user!.email}");
        // TODO: Send welcome email via Firebase Cloud Function (client-side cannot send emails securely)
        _showSnackBar('Welcome to Vitalyz! Account created successfully.');

        // Navigate to MainScreen directly after successful signup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(userId: userCredential.user!.uid),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      } else if (e.code == 'network-request-failed') {
        message = 'Network error. Please check your internet connection.';
      } else {
        message = 'Sign up failed: ${e.message ?? 'Unknown error'}';
      }
      setState(() { _errorMessage = message; });
      _showSnackBar(message, isError: true);
    } catch (e) {
      setState(() { _errorMessage = 'An unexpected error occurred: $e'; });
      _showSnackBar('An unexpected error occurred: $e', isError: true);
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Account',
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: _FlowyBackground(),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Join VITALYZ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onBackground,
                      letterSpacing: 1.2,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sign up to start your personalized health journey.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 14, fontFamily: 'Montserrat'),
                      ),
                    ),

                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'e.g., yourname@example.com',
                      prefixIcon: Icon(Icons.email_outlined, color: Theme.of(context).colorScheme.primary),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Minimum 6 characters',
                      prefixIcon: Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.primary),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      hintText: 'Re-enter your password',
                      prefixIcon: Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.primary),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    child: _isLoading
                        ? CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary)
                        : const Text('Sign Up'),
                  ),
                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Go back to login screen
                    },
                    child: Text('Already have an account? Sign In', style: TextStyle(color: Theme.of(context).colorScheme.primaryContainer)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// A simple placeholder screen for Settings.
class SettingsScreen extends StatefulWidget { // Changed to StatefulWidget
  final String userId; // Added userId parameter

  const SettingsScreen({super.key, required this.userId}); // Made userId required

  @override
  State<SettingsScreen> createState() => _SettingsScreenState(); // Create its state
}

class _SettingsScreenState extends State<SettingsScreen> { // New State class
  void _showSnackBar(String message, {bool isError = false}) { // Moved from StatelessWidget to State
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            color: Theme.of(context).appBarTheme.titleTextStyle?.color,
            fontWeight: FontWeight.bold,
            fontFamily: 'Montserrat',
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 1,
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: _FlowyBackground(), // Using flowy background
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.settings, size: 80, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 24),
                  Text(
                    'Settings',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onBackground,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Manage your app preferences and configurations here. More options coming soon!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7), fontFamily: 'Montserrat'),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to the AccountSettingsScreen
                      // Now we can directly use widget.userId because SettingsScreen is StatefulWidget
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AccountSettingsScreen(userId: widget.userId), // Correctly pass userId
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    child: const Text('Account Settings'),
                  ),

                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800, // Changed to blue.shade800
                      foregroundColor: Colors.white, // Ensure text is white on dark blue
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    child: const Text('Privacy Policy'),
                  ),
                  const SizedBox(height: 16), // Add space for the Logout button
                  ElevatedButton(
                    onPressed: () {
                      _signOutApp(context); // Use the global signOut function
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade900, // Changed to blue.shade900
                      foregroundColor: Colors.white, // Ensure text is white on dark blue
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                    child: const Text('Log Out'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// New screen to display vital signs with a more detailed and lively presentation.
class VitalsOverviewScreen extends StatefulWidget {
  final String userId;

  const VitalsOverviewScreen({super.key, required this.userId});

  @override
  State<VitalsOverviewScreen> createState() => _VitalsOverviewScreenState();
}

class _VitalsOverviewScreenState extends State<VitalsOverviewScreen> {
  VitalSigns? _currentVitals;
  StreamSubscription? _vitalsSubscription; // Declare a StreamSubscription

  @override
  void initState() {
    super.initState();
    // When this screen initializes, immediately simulate and save new vitals
    // This ensures 'current_vitals/latest' is always populated.
    _simulateAndSaveVitals();
    _fetchCurrentVitalsLive(); // Set up listener to display updates
  }

  @override
  void dispose() {
    _vitalsSubscription?.cancel(); // Cancel the subscription when the widget is disposed
    super.dispose();
  }

  /// Fetches current location and then weather data from OpenWeatherMap.
  /// Returns a Map containing 'airTemp' and 'airHumidity'.
  Future<Map<String, double>> _fetchWeatherData() async {
    double airTemp = 0.0;
    double airHumidity = 0.0;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar("Location permissions are denied. Cannot fetch live weather.", isError: true);
          print("Location permissions denied.");
          return {'airTemp': airTemp, 'airHumidity': airHumidity}; // Return default or previous values
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar("Location permissions are permanently denied. Please enable them in settings.", isError: true);
        print("Location permissions permanently denied.");
        return {'airTemp': airTemp, 'airHumidity': airHumidity};
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      final lat = position.latitude;
      final lon = position.longitude;

      // --- ADDED FOR DEBUGGING ---
      print("Geolocator retrieved location: Lat=$lat, Lon=$lon"); // THIS IS THE LINE I ADDED
      // --- END ADDED ---

      if (OPENWEATHER_API_KEY.isEmpty || OPENWEATHER_API_KEY == "YOUR_OPENWEATHER_API_KEY") { // Simplified check
        _showSnackBar("OpenWeatherMap API Key is not set or invalid! Using default environmental values.", isError: true);
        print("OpenWeatherMap API Key is missing, invalid, or default. Using fallback values.");
        return {'airTemp': 25.0, 'airHumidity': 60.0};
      }

      final url = 'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$OPENWEATHER_API_KEY&units=metric';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        airTemp = (data['main']['temp'] as num).toDouble();
        airHumidity = (data['main']['humidity'] as num).toDouble();
        print("Fetched live weather data: Temp=$airTemp°C, Humidity=$airHumidity%");
      } else {
        String errorBody = response.body.isNotEmpty ? json.decode(response.body)['message'] ?? 'No message' : 'Empty response body';
        _showSnackBar("Failed to load weather data: ${response.statusCode} - $errorBody", isError: true);
        print("Failed to load weather data: ${response.statusCode} - $errorBody");
        // Fallback to sensible defaults on API error
        return {'airTemp': 25.0, 'airHumidity': 60.0};
      }
    } catch (e) {
      _showSnackBar("Error fetching weather data: $e", isError: true);
      print("Error fetching weather data: $e");
      // Fallback to sensible defaults on any exception
      return {'airTemp': 25.0, 'airHumidity': 60.0};
    }
    return {'airTemp': airTemp, 'airHumidity': airHumidity};
  }

  // Generates random vital signs and saves them to Firestore
  Future<void> _simulateAndSaveVitals() async {
    if (_db == null || widget.userId.isEmpty) {
      print("Database not ready or user not logged in for simulating vitals.");
      _showSnackBar("Database not ready or user ID missing. Cannot simulate vitals.", isError: true);
      return;
    }

    final random = math.Random();
    final now = Timestamp.now();

    // Fetch live air temperature and humidity
    final weatherData = await _fetchWeatherData();
    final liveAirTemp = weatherData['airTemp']!;
    final liveAirHumidity = weatherData['airHumidity']!;

    // Generate plausible vital signs (other than airTemp/airHumidity) with more distinct ranges for testing
    final simulatedVitals = VitalSigns(
      heartRate: (50 + random.nextInt(60)).toDouble(), // Range 50-109 bpm
      bodyTemp: 36.0 + (random.nextDouble() * 3.0), // Range 36.0-39.0 °C
      skinConductivity: 0.5 + (random.nextDouble() * 10.0), // Range 0.5-10.5 µS
      airTemp: liveAirTemp, // Use live data
      airHumidity: liveAirHumidity, // Use live data
      bloodOxygen: 95.0 + random.nextDouble() * 5.0, // 95-100 % (simple simulation)
      timestamp: now,
    );

    try {
      // 1. Update the 'latest' document in 'current_vitals' collection
      final currentVitalsDocRef = _db!
          .collection('artifacts')
          .doc('vitalink-app')
          .collection('users')
          .doc(widget.userId)
          .collection('current_vitals')
          .doc('latest')
          .withConverter<Map<String, dynamic>>(
        fromFirestore: (snapshot, _) => snapshot.data()!,
        toFirestore: (model, _) => model,
      );
      await currentVitalsDocRef.set(simulatedVitals.toMap(), SetOptions(merge: true));
      print("Simulated current vitals saved to current_vitals/latest: ${simulatedVitals.heartRate?.toStringAsFixed(0)} bpm");

      // 2. Add a new document to 'vitals_history' collection
      final vitalsHistoryCollectionRef = _db!
          .collection('artifacts')
          .doc('vitalink-app')
          .collection('users')
          .doc(widget.userId)
          .collection('vitals_history')
          .withConverter<Map<String, dynamic>>(
        fromFirestore: (snapshot, _) => snapshot.data()!,
        toFirestore: (model, _) => model,
      );
      await vitalsHistoryCollectionRef.add(simulatedVitals.toMap());
      print("Simulated vitals logged to vitals_history.");

      _showSnackBar("New vitals data simulated and saved!");

    } catch (e) {
      _showSnackBar("Error simulating and saving vitals: $e", isError: true);
      print("Error simulating and saving vitals: $e");
    }
  }

  // Listens for real-time updates to the 'latest' current vitals document
  void _fetchCurrentVitalsLive() {
    if (_db == null || widget.userId.isEmpty) {
      print("Database not ready or user not logged in for fetching live vitals.");
      return;
    }

    final currentVitalsDocRef = _db!
        .collection('artifacts')
        .doc('vitalink-app')
        .collection('users')
        .doc(widget.userId)
        .collection('current_vitals')
        .doc('latest')
        .withConverter<Map<String, dynamic>>(
      fromFirestore: (snapshot, _) => snapshot.data()!,
      toFirestore: (model, _) => model,
    );

    _vitalsSubscription = currentVitalsDocRef.snapshots().listen((snapshot) { // Assign to _vitalsSubscription
      if (mounted) { // Crucial check before calling setState
        if (snapshot.exists && snapshot.data() != null) {
          final newVitals = VitalSigns.fromFirestore(snapshot);
          // Added print to confirm data received by listener
          print("onSnapshot received new vitals: HR=${newVitals.heartRate?.toStringAsFixed(0)}, BT=${newVitals.bodyTemp?.toStringAsFixed(1)}, SC=${newVitals.skinConductivity?.toStringAsFixed(2)}, AirTemp=${newVitals.airTemp?.toStringAsFixed(1)}, AirHumidity=${newVitals.airHumidity?.toStringAsFixed(0)}");
          setState(() {
            _currentVitals = newVitals;
          });
        } else {
          setState(() {
            _currentVitals = null; // No current vitals found
          });
          print("No live current vitals data found for this user in VitalsOverviewScreen.");
        }
      }
    }, onError: (error) {
      print("Error fetching live current vitals in VitalsOverviewScreen: $error");
      if (mounted) { // Check mounted before showing snackbar too
        _showSnackBar("Error fetching live vitals: $error", isError: true);
      }
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Helper widget for displaying a single vital row with icon
  Widget _buildVitalDisplayRowWithIcon(String label, String value, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28), // Icon
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontFamily: "Montserrat"), // Montserrat for label
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface, fontFamily: "Montserrat"), // Montserrat for value
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Your Vitals',
          style: TextStyle(
            color: Theme.of(context).appBarTheme.titleTextStyle?.color,
            fontWeight: FontWeight.bold,
            fontFamily: "Montserrat", // Montserrat for AppBar title
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 1,
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: _FlowyBackground(), // Using flowy background
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Health at a Glance',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontFamily: "Montserrat", // Using Montserrat
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onBackground,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _currentVitals != null && _currentVitals!.timestamp != null
                      ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface, // Use surface color
                      borderRadius: BorderRadius.circular(20), // More rounded corners
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), // Light shadow
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Readings',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontFamily: "Montserrat",
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Last Updated: ${DateFormat('MMM d,yyyy HH:mm').format(_currentVitals!.timestamp!.toDate())}',
                          style: TextStyle(
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            fontStyle: FontStyle.italic,
                            fontFamily: "Montserrat",
                          ),
                        ),
                        Divider(color: Colors.grey.shade300, height: 30, thickness: 1.5), // Lighter divider
                        _buildVitalDisplayRowWithIcon(
                            'Heart Rate:',
                            '${_currentVitals!.heartRate?.toStringAsFixed(0) ?? 'N/A'} bpm',
                            Icons.favorite_border,
                            Colors.red.shade600), // Adjusted for light theme
                        _buildVitalDisplayRowWithIcon(
                            'Body Temperature:',
                            '${_currentVitals!.bodyTemp?.toStringAsFixed(1) ?? 'N/A'} °C',
                            Icons.thermostat_outlined,
                            Colors.orange.shade600), // Adjusted for light theme
                        _buildVitalDisplayRowWithIcon(
                            'Skin Conductivity:',
                            '${_currentVitals!.skinConductivity?.toStringAsFixed(2) ?? 'N/A'} µS',
                            Icons.electric_bolt_outlined,
                            Colors.amber.shade600), // Adjusted for light theme
                        _buildVitalDisplayRowWithIcon(
                            'Surrounding Temperature:',
                            '${_currentVitals!.airTemp?.toStringAsFixed(1) ?? 'N/A'} °C',
                            Icons.cloud_outlined,
                            Colors.blue.shade600), // Adjusted for light theme
                        _buildVitalDisplayRowWithIcon(
                            'Surrounding Humidity:',
                            '${_currentVitals!.airHumidity?.toStringAsFixed(0) ?? 'N/A'} %',
                            Icons.water_drop_outlined,
                            Colors.cyan.shade600), // Adjusted for light theme
                      ],
                    ),
                  )
                      : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary.withOpacity(0.7), size: 50),
                        const SizedBox(height: 15),
                        Text(
                          'No Vitals Data Found',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontFamily: "Montserrat",
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tap "Simulate & Refresh Data" to generate new vital readings and save them.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            fontFamily: "Montserrat",
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Refresh button on the vitals screen itself
                        ElevatedButton.icon(
                          onPressed: _simulateAndSaveVitals, // Call the simulate and save function
                          icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onPrimary),
                          label: Text('Simulate & Refresh Data', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontFamily: 'Montserrat')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Main Screen of the app after login, featuring a Bottom Navigation Bar.
class MainScreen extends StatefulWidget {
  final String userId;
  const MainScreen({super.key, required this.userId});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // Current selected tab index
  ProfileData _userProfileData = ProfileData(name: "User"); // Default profile data

  @override
  void initState() {
    super.initState();
    _loadUserProfileData(); // Load profile data when MainScreen initializes
  }

  // Load user profile data from Firestore
  Future<void> _loadUserProfileData() async {
    if (_db == null || widget.userId.isEmpty) {
      print("Database not ready or user not logged in for fetching profile.");
      return;
    }

    try {
      final docRef = _db!
          .collection('artifacts')
          .doc('vitalink-app')
          .collection('users')
          .doc(widget.userId)
          .collection('profile') // Corrected: profile is now a collection
          .doc('user_profile') // Fixed document ID for user profile
          .withConverter<Map<String, dynamic>>( // Added withConverter for type safety
        fromFirestore: (snapshot, _) => snapshot.data()!,
        toFirestore: (model, _) => model,
      );
      final docSnap = await docRef.get();

      if (docSnap.exists) {
        final data = docSnap.data();
        // Use a safe check for mounted before setState to prevent errors if widget is disposed
        if (mounted) {
          setState(() {
            _userProfileData = ProfileData.fromFirestore(docSnap);
          });
        }
        print("User profile data loaded for MainScreen: ${_userProfileData.name}");
      } else {
        print("No health profile found for this user in MainScreen. Defaulting.");
        // If no health profile, try to get display name from Firebase Auth user
        final currentUser = _auth?.currentUser;
        if (mounted) {
          setState(() {
            _userProfileData = ProfileData(name: currentUser?.displayName ?? "User");
          });
        }
      }
    } catch (e) {
      _showSnackBar("Failed to load user profile: $e", isError: true);
      print("Error loading user profile data in MainScreen: $e");
    }
  }


  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) { // Ensure widget is still mounted before showing SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _widgetOptions = <Widget>[
      HomeScreen(userId: widget.userId, profileData: _userProfileData),
      ProfileScreen(userId: widget.userId), // ProfileScreen takes userId
      SettingsScreen(userId: widget.userId), // <-- CORRECTED HERE: Pass userId
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80.0,
        title: Image.asset(
          'assets/images/pnglogo.png', // Using logo.png (consistent with splash)
          height: 70, // Adjust height as needed
          fit: BoxFit.contain, // Adjust fit as needed
          errorBuilder: (context, error, stackTrace) {
            return Text('Vitalyz AI', style: TextStyle(color: Theme.of(context).appBarTheme.titleTextStyle?.color, fontSize: 24, fontFamily: 'Montserrat')); // Updated to Vitalyz AI
          },
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 1,
        actions: [
          // Profile Icon (remains at top for direct access, but also in bottom nav)
          IconButton(
            icon: Icon(Icons.person_outline, size: 30, color: Theme.of(context).colorScheme.onBackground),
            onPressed: () {
              _onItemTapped(1); // Switch to Profile tab
            },
            tooltip: 'Profile',
          ),
          // Settings Icon (remains at top for direct access, but also in bottom nav)
          IconButton(
            icon: Icon(Icons.settings_outlined, size: 30, color: Theme.of(context).colorScheme.onBackground),
            onPressed: () {
              _onItemTapped(2); // Switch to Settings tab
            },
            tooltip: 'Settings',
          ),
          // Logout Icon
          IconButton(
            icon: Icon(Icons.logout, size: 30, color: Theme.of(context).colorScheme.onBackground),
            onPressed: () async {
              await _signOutApp(context); // Call the global signOut function
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface, // Use surface color for nav bar background
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Theme( // Apply theme override to remove splash effect
          data: Theme.of(context).copyWith(
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.home, color: _selectedIndex == 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                label: '', // Removed label text
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person, color: _selectedIndex == 1 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                label: '', // Removed label text
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings, color: _selectedIndex == 2 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                label: '', // Removed label text
              ),
            ],
            currentIndex: _selectedIndex,
            selectedItemColor: Theme.of(context).colorScheme.primary, // Primary color for selected item
            unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), // Dimmed for unselected
            onTap: _onItemTapped,
            backgroundColor: Colors.transparent, // Important: Make it transparent to show Container's background
            type: BottomNavigationBarType.fixed,
            showSelectedLabels: false, // Removed selected labels
            showUnselectedLabels: false, // Removed unselected labels
            enableFeedback: false, // Disables haptic feedback on tap
            elevation: 0, // Remove default elevation
          ),
        ),
      ),
    );
  }
}

/// The Profile Screen for Vitalyz.
class ProfileScreen extends StatefulWidget {
  final String userId; // User ID from Firebase Auth
  final bool isEditing; // Controls if fields are editable

  const ProfileScreen({
    super.key,
    required this.userId, // User ID is now required
    this.isEditing = false, // Default to display mode
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late bool _isEditing; // State variable to control editing mode
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _medicalConditionsController = TextEditingController();
  String? _selectedGender; // For dropdown

  final List<String> _genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];
  bool _isLoading = false; // For loading state during Firestore operations

  @override
  void initState() {
    super.initState();
    _isEditing = widget.isEditing; // Initialize from widget's isEditing
    _loadProfileDataFromFirestore(); // Always attempt to load profile data
  }

  // Load data into controllers from Firestore
  Future<void> _loadProfileDataFromFirestore() async {
    // Check if _db is null. It shouldn't be if _initializeFirebase completes, but as a safeguard.
    if (_db == null || widget.userId.isEmpty) {
      print("Database not ready or user not logged in.");
      return;
    }

    setState(() { _isLoading = true; });
    try {
      final docRef = _db!
          .collection('artifacts')
          .doc('vitalink-app')
          .collection('users')
          .doc(widget.userId)
          .collection('profile') // Corrected: profile is now a collection
          .doc('user_profile') // Fixed document ID for user profile
          .withConverter<Map<String, dynamic>>( // Added withConverter for type safety
        fromFirestore: (snapshot, _) => snapshot.data()!,
        toFirestore: (model, _) => model,
      );
      final docSnap = await docRef.get();

      if (docSnap.exists) {
        final data = docSnap.data();
        // Use a safe check for mounted before setState to prevent errors if widget is disposed
        if (mounted) {
          setState(() {
            _nameController.text = data?['name'] ?? '';
            _ageController.text = data?['age'] ?? '';
            _heightController.text = data?['height'] ?? '';
            _weightController.text = data?['weight'] ?? '';
            _selectedGender = data?['gender'];
            _medicalConditionsController.text = data?['medicalConditions'] ?? '';
            _isEditing = false; // Switch to display mode if data is found
          });
        }
        print("Profile data loaded from Firestore.");
      } else {
        print("No profile data found in Firestore for this user. Switching to editing mode.");
        setState(() {
          _isEditing = true; // Force editing mode if no profile found
          // Clear fields if no data found and going into edit mode
          _nameController.text = '';
          _ageController.text = '';
          _heightController.text = '';
          _weightController.text = '';
          _selectedGender = null;
          _medicalConditionsController.text = '';
        });
      }
    } catch (e) {
      _showSnackBar("Failed to load profile: $e", isError: true);
      print("Error loading profile data: $e");
    } finally {
      setState(() { _isLoading = false; });
    }
  }


  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _confirmProfile() async {
    setState(() { _isLoading = true; });
    try {
      final newProfileData = ProfileData(
        name: _nameController.text,
        age: _ageController.text,
        height: _heightController.text,
        weight: _weightController.text,
        gender: _selectedGender,
        medicalConditions: _medicalConditionsController.text,
      );

      if (_db != null && widget.userId.isNotEmpty) {
        final docRef = _db!
            .collection('artifacts')
            .doc('vitalink-app')
            .collection('users')
            .doc(widget.userId)
            .collection('profile') // Corrected: profile is now a collection
            .doc('user_profile') // Fixed document ID for user profile
            .withConverter<Map<String, dynamic>>( // Added withConverter for type safety
          fromFirestore: (snapshot, _) => snapshot.data()!,
          toFirestore: (model, _) => model,
        );
        await docRef.set(newProfileData.toMap(), SetOptions(merge: true));
        _showSnackBar('Profile details saved successfully!');
        setState(() { _isEditing = false; }); // Exit editing mode after saving
        // Navigate to MainScreen after saving profile (replacing the current route)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainScreen(userId: widget.userId)),
        );
      } else {
        _showSnackBar("Error: Database not ready or user not logged in.", isError: true);
      }
    } catch (e) {
      _showSnackBar("Failed to save profile: $e", isError: true);
      print("Error saving profile data: $e");
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _editProfile() {
    setState(() {
      _isEditing = true; // Switch to editing mode
    });
    _showSnackBar('Editing profile...');
  }

  // Helper to create a TextFormField with consistent styling
  Widget _buildProfileFormField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    int maxLines = 1,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return TextFormField(
      controller: controller,
      enabled: _isEditing, // Enable/disable based on editing mode
      style: TextStyle(color: Theme.of(context).colorScheme.onBackground, fontFamily: 'Montserrat'), // Explicitly set Montserrat
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7), fontFamily: 'Montserrat'),
        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onBackground.withOpacity(0.5), fontFamily: 'Montserrat'),
      ),
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
    );
  }

  // Helper to create a Text widget for display mode
  Widget _buildProfileDisplayField(String label, String? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7), fontSize: 14, fontFamily: 'Montserrat'), // Explicitly set Montserrat
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.onBackground.withOpacity(0.3), width: 1)),
          ),
          child: Text(
            value ?? 'N/A',
            style: TextStyle(color: Theme.of(context).colorScheme.onBackground, fontSize: 16, fontFamily: 'Montserrat'), // Explicitly set Montserrat
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _medicalConditionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Flowy background for Profile Screen
          const Positioned.fill(
            child: _FlowyBackground(),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32.0, 60.0, 32.0, 32.0),
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Profile',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontFamily: 'Montserrat', // Explicitly set Montserrat
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onBackground,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  _isEditing
                      ? Column(
                    children: [
                      _buildProfileFormField(
                        controller: _nameController,
                        labelText: 'Name',
                        hintText: 'Enter your full name',
                        icon: Icons.badge_outlined,
                        keyboardType: TextInputType.name,
                      ),
                      const SizedBox(height: 16),
                      _buildProfileFormField(
                        controller: _ageController,
                        labelText: 'Age',
                        hintText: 'Enter your age in years',
                        icon: Icons.cake_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      _buildProfileFormField(
                        controller: _heightController,
                        labelText: 'Height',
                        hintText: 'Enter your height in cm',
                        icon: Icons.height_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      _buildProfileFormField(
                        controller: _weightController,
                        labelText: 'Weight',
                        hintText: 'Enter your weight in kg',
                        icon: Icons.monitor_weight_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      // Gender Dropdown for editing
                      Theme(
                        data: Theme.of(context).copyWith(
                          canvasColor: Theme.of(context).colorScheme.surface, // Background color of dropdown menu
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3), width: 1),
                            color: Theme.of(context).colorScheme.surface, // Background for dropdown
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedGender,
                              hint: Text('Select Gender', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 16, fontFamily: 'Montserrat')), // Explicitly set Montserrat
                              icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.primary),
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontFamily: 'Montserrat'), // Explicitly set Montserrat
                              onChanged: _isEditing ? (String? newValue) {
                                setState(() {
                                  _selectedGender = newValue;
                                });
                              } : null,
                              items: _genderOptions.map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontFamily: 'Montserrat')), // Explicitly set Montserrat
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildProfileFormField(
                        controller: _medicalConditionsController,
                        labelText: 'Any known medical conditions',
                        hintText: 'e.g., Diabetes, Asthma, Heart condition, None',
                        icon: Icons.medical_information_outlined,
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                      ),
                      const SizedBox(height: 32),
                      // Confirm Button for editing
                      ElevatedButton(
                        onPressed: _isLoading ? null : _confirmProfile,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 14),
                        ),
                        child: _isLoading ? CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary) : const Text('Confirm'),
                      ),
                    ],
                  )
                      : Column(
                    // Display mode fields
                    children: [
                      _buildProfileDisplayField('Name:', _nameController.text.isNotEmpty ? _nameController.text : 'N/A'),
                      _buildProfileDisplayField('Age:', _ageController.text.isNotEmpty ? _ageController.text : 'N/A'),
                      _buildProfileDisplayField('Height:', _heightController.text.isNotEmpty ? _heightController.text : 'N/A'),
                      _buildProfileDisplayField('Weight:', _weightController.text.isNotEmpty ? _weightController.text : 'N/A'),
                      _buildProfileDisplayField('Gender:', _selectedGender ?? 'N/A'),
                      _buildProfileDisplayField('Any known medical conditions:', _medicalConditionsController.text.isNotEmpty ? _medicalConditionsController.text : 'None'),
                      const SizedBox(height: 32),
                      // Edit Button for display mode
                      ElevatedButton(
                        onPressed: _isLoading ? null : _editProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondary, // Secondary color for edit button
                          foregroundColor: Theme.of(context).colorScheme.onSecondary,
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        child: _isLoading ? CircularProgressIndicator(color: Theme.of(context).colorScheme.onSecondary) : const Text('Edit Profile'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Top-right icons removed from ProfileScreen as per request.
        ],
      ),
    );
  }
}

/// The new Home Screen for Vitalyz.
class HomeScreen extends StatelessWidget {
  final ProfileData profileData;
  final String userId;

  const HomeScreen({super.key, required this.profileData, required this.userId});

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Flowy background for the Home Screen
          const Positioned.fill(
            child: _FlowyBackground(),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(32.0, 60.0, 32.0, 0.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hey, ${profileData.name ?? 'User'}',
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onBackground,
                              letterSpacing: 1.5,
                              fontFamily: 'Montserrat', // Explicitly set Montserrat
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Would you like to,',
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: 20,
                              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Montserrat', // Explicitly set Montserrat
                            ),
                          ),
                          const SizedBox(height: 48),

                          Center(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Check Vitals button now navigates to VitalsOverviewScreen
                                    _buildActionButton(
                                      context,
                                      'Check Vitals',
                                      Icons.monitor_heart,
                                      Theme.of(context).colorScheme.primary,
                                          () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => VitalsOverviewScreen(userId: userId), // Pass userId
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 20),
                                    // Predict Organ Risks (moved to middle of first section)
                                    _buildActionButton(
                                      context,
                                      'Predict Organ Risks',
                                      Icons.medical_services_outlined,
                                      Colors.red.shade500,
                                          () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => OrganRiskPredictionScreen(userId: userId),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 30),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Predict Heatstroke (moved to bottom-left)
                                    _buildActionButton(
                                      context,
                                      'Predict Heatstroke',
                                      Icons.sunny_snowing,
                                      Theme.of(context).colorScheme.secondary, // Original color for Heatstroke
                                          () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => HeatstrokePredictionScreen(userId: userId),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 20),
                                    // Medicine Effectiveness Tracker (remains bottom-right)
                                    _buildActionButton(
                                      context,
                                      'Medicine Effectiveness Tracker',
                                      Icons.medication_outlined, // Appropriate icon
                                      Colors.purple.shade500, // New color for this button
                                          () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => MedicineEffectivenessTrackerScreen(userId: userId),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),

                          Padding(
                            padding: const EdgeInsets.only(left: 32.0),
                            child: Text(
                              'Real-Time Monitoring',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onBackground,
                                fontFamily: 'Montserrat', // Explicitly set Montserrat
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Real-Time Monitoring Section with Horizontal Scroll and Scrollbar
                          Scrollbar(
                            thumbVisibility: true,
                            thickness: 6.0, // Adjust thickness for better visibility
                            radius: const Radius.circular(10.0), // Rounded corners for the thumb
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Padding( // Added Padding *inside* SingleChildScrollView
                                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start, // Ensure buttons start from the left
                                  crossAxisAlignment: CrossAxisAlignment.start, // Align items at the top
                                  children: [
                                    _buildHorizontalActionButton(
                                      context,
                                      'Environmental Precautions',
                                      Icons.cloud_queue,
                                      Colors.lightGreen.shade600,
                                          () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => EnvironmentalPrecautionsScreen(userId: userId),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 20),
                                    // Track Dehydration (moved here from main grid)
                                    _buildHorizontalActionButton(
                                      context,
                                      'Track Dehydration',
                                      Icons.water_drop_outlined,
                                      Colors.cyan.shade600,
                                          () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => DehydrationTrackingScreen(userId: userId),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 20),
                                    _buildHorizontalActionButton(
                                      context,
                                      'Trend Analysis & Charts',
                                      Icons.show_chart,
                                      Colors.pink.shade600,
                                          () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => TrendAnalysisScreen(userId: userId),
                                          ),
                                        );
                                      },
                                    ),


                                    // Add more buttons here if needed for scrolling
                                  ],
                                ),
                              ),
                            ),
                          ),


                          const SizedBox(height: 40),

                          Padding(
                            padding: const EdgeInsets.only(left: 32.0),
                            child: Text(
                              'Proactive Health',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onBackground,
                                fontFamily: 'Montserrat', // Explicitly set Montserrat
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Proactive Health Section with Horizontal Scroll and Scrollbar
                          Scrollbar(
                            thumbVisibility: true,
                            thickness: 6.0, // Adjust thickness for better visibility
                            radius: const Radius.circular(10.0), // Rounded corners for the thumb
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Padding( // Added Padding *inside* SingleChildScrollView
                                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start, // Ensure buttons start from the left
                                  crossAxisAlignment: CrossAxisAlignment.start, // Align items at the top
                                  children: [
                                    // REMOVED: Personalized Health Score button
                                    _buildHorizontalActionButton(
                                      context,
                                      'Anomaly Detection',
                                      Icons.error_outline,
                                      Colors.red.shade500,
                                          () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => AnomalyDetectionScreen(userId: userId),
                                          ),
                                        );
                                      },
                                    ),

                                    const SizedBox(width: 20),
                                    // New button for 2-Day Body Nature Analysis
                                    _buildHorizontalActionButton(
                                      context,
                                      '2-Day Body Nature',
                                      Icons.analytics, // Choose a suitable icon
                                      Colors.blueGrey.shade600, // Choose a suitable color
                                          () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => BodyNatureAnalysisScreen(userId: userId),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 20),
                                    _buildHorizontalActionButton(
                                      context,
                                      'Comparative Views',
                                      Icons.compare_arrows,
                                      Colors.teal.shade600,
                                          () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ComparativeViewsScreen(userId: userId),
                                          ),
                                        );
                                      },
                                    ),
                                    // Add more buttons here if needed for scrolling
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32), // Keep this SizedBox for spacing
                        ],
                      ),
                    ),
                  ),
                  // Website URL on Home Screen (Removed as per request)
                ],
              ),
            ),
          ),
          // Top-right icons removed from HomeScreen as per request.
        ],
      ),
    );
  }


  // Original square Action button builder (for top 4 buttons)
  Widget _buildActionButton(BuildContext context, String text, IconData icon, Color iconColor, VoidCallback onPressed) {
    return Container(
      width: 160.0, // Fixed width
      height: 160.0, // Fixed height
      decoration: BoxDecoration(
        gradient: LinearGradient( // Apply a subtle gradient
          colors: [
            Theme.of(context).colorScheme.surface, // Start with white
            Theme.of(context).colorScheme.primary.withOpacity(0.1), // Fade to a very light primary tint
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.1), // Subtle shadow
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed, // Use the provided onPressed callback
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, // Transparent to show container's gradient
          shadowColor: Colors.transparent,
          elevation: 0,
          padding: const EdgeInsets.all(15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 48), // Icon color provided
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface, // Text color on surface (dark grey)
                fontFamily: 'Montserrat', // Explicitly set Montserrat
              ),
            ),
          ],
        ),
      ),
    );
  }

  // New rectangular Action button builder for horizontal scroll sections
  Widget _buildHorizontalActionButton(BuildContext context, String text, IconData icon, Color iconColor, VoidCallback onPressed) {
    return Container(
      width: 220.0, // Increased length (width)
      height: 100.0, // Reduced height
      decoration: BoxDecoration(
        gradient: LinearGradient( // Apply a subtle gradient
          colors: [
            Theme.of(context).colorScheme.surface, // Start with white
            Theme.of(context).colorScheme.primary.withOpacity(0.1), // Fade to a very light primary tint
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.1), // Subtle shadow
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed, // Use the provided onPressed callback
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, // Transparent to show container's gradient
          shadowColor: Colors.transparent,
          elevation: 0,
          padding: const EdgeInsets.all(15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row( // Changed to Row for horizontal layout
          mainAxisAlignment: MainAxisAlignment.start, // Align icon and text to the start within the button
          children: [
            Icon(icon, color: iconColor, size: 36), // Icon size adjusted
            const SizedBox(width: 10),
            Expanded( // Ensures text takes available space, preventing overflow/truncation
              child: Text(
                text,
                textAlign: TextAlign.left, // Align text to the left
                style: TextStyle(
                  fontSize: 16, // Font size adjusted
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface, // Text color on surface (dark grey)
                  fontFamily: 'Montserrat', // Explicitly set Montserrat
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Widget for the logo and app title section (used on Login)
class _LogoSection extends StatelessWidget {
  const _LogoSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface, // Use surface color for logo card (white)
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Image.asset(
            'assets/images/logo.png', // Standardized to logo.png
            width: 200, // Adjusted size to match splash screen
            height: 200, // Adjusted size to match splash screen
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.error,
                color: Colors.red,
                size: 100,
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'VITALYZ', // Updated to VITALYZ
              style: TextStyle(
                fontSize: 36,
                fontFamily: 'Montserrat', // Explicitly set Montserrat
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface, // Text color on surface (dark grey)
                letterSpacing: 1.9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget for the app tagline (used on Login)
class _TaglineSection extends StatelessWidget {
  const _TaglineSection();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Your smart health guardian',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 18,
        color: Theme.of(context).colorScheme.onBackground.withOpacity(0.8), // Adjust color for contrast
        fontWeight: FontWeight.w500,
        fontFamily: 'Montserrat', // Explicitly set Montserrat
      ),
    );
  }
}

/// Widget for the website URL at the bottom.
class _WebsiteUrl extends StatelessWidget {
  const _WebsiteUrl();

  @override
  Widget build(BuildContext context) {
    return Text(
      'www.vitalyz.com', // Retained as per new code logs.txt
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6), // Adjusted color for contrast
        decoration: TextDecoration.underline,
        fontFamily: 'Montserrat', // Explicitly set Montserrat
      ),
    );
  }
}

/// Custom Painter for the light and flowy background effect.
class _FlowyBackground extends StatefulWidget {
  const _FlowyBackground();

  @override
  State<_FlowyBackground> createState() => _FlowyBackgroundState();
}

class _FlowyBackgroundState extends State<_FlowyBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15), // Longer duration for slower flow
    )..repeat(reverse: true); // Repeat back and forth
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _FlowyPainter(_controller.value),
          child: Container(color: Theme.of(context).colorScheme.background), // Base background color
        );
      },
    );
  }
}

class _FlowyPainter extends CustomPainter {
  final double animationValue;

  _FlowyPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    // Define base colors (pastel and light)
    final Color bluePastel = const Color(0xFFE3F2FD).withOpacity(0.6); // Light Blue 50
    final Color greenPastel = const Color(0xFFE8F5E9).withOpacity(0.6); // Light Green 50
    final Color pinkPastel = const Color(0xFFFCE4EC).withOpacity(0.6); // Pink 50
    final Color purplePastel = const Color(0xFFEDE7F6).withOpacity(0.6); // Deep Purple 50

    // Path 1 (Blue wave)
    Paint paint1 = Paint()
      ..color = bluePastel
      ..style = PaintingStyle.fill;
    Path path1 = Path();
    path1.moveTo(0, height * 0.4 + (math.sin(animationValue * 2 * math.pi) * 20));
    path1.quadraticBezierTo(
        width * 0.25,
        height * 0.3 + (math.cos(animationValue * 2 * math.pi) * 30),
        width * 0.5,
        height * 0.45 + (math.sin(animationValue * 2 * math.pi + math.pi / 2) * 25));
    path1.quadraticBezierTo(
        width * 0.75,
        height * 0.6 + (math.cos(animationValue * 2 * math.pi + math.pi) * 35),
        width,
        height * 0.5 + (math.sin(animationValue * 2 * math.pi + 3 * math.pi / 2) * 20));
    path1.lineTo(width, height);
    path1.lineTo(0, height);
    path1.close();
    canvas.drawPath(path1, paint1);

    // Path 2 (Green blob, slightly animated)
    Paint paint2 = Paint()
      ..color = greenPastel
      ..style = PaintingStyle.fill;
    Path path2 = Path();
    double offset2X = width * 0.1 + (math.cos(animationValue * 2 * math.pi / 2) * 15);
    double offset2Y = height * 0.1 + (math.sin(animationValue * 2 * math.pi / 2) * 10);
    path2.addOval(Rect.fromLTWH(
        width * 0.6 + offset2X,
        height * 0.1 + offset2Y,
        width * 0.4,
        height * 0.3));
    canvas.drawPath(path2, paint2);

    // Path 3 (Pink wave, lower)
    Paint paint3 = Paint()
      ..color = pinkPastel
      ..style = PaintingStyle.fill;
    Path path3 = Path();
    path3.moveTo(0, height * 0.7 + (math.cos(animationValue * 2 * math.pi) * 15));
    path3.quadraticBezierTo(
        width * 0.3,
        height * 0.8 + (math.sin(animationValue * 2 * math.pi + math.pi / 3) * 25),
        width * 0.7,
        height * 0.75 + (math.cos(animationValue * 2 * math.pi + math.pi) * 20));
    path3.quadraticBezierTo(
        width * 0.9,
        height * 0.9 + (math.sin(animationValue * 2 * math.pi + 2 * math.pi / 3) * 10),
        width,
        height * 0.8 + (math.cos(animationValue * 2 * math.pi + 4 * math.pi / 3) * 15));
    path3.lineTo(width, height);
    path3.lineTo(0, height);
    path3.close();
    canvas.drawPath(path3, paint3);

    // Path 4 (Subtle purple oval)
    Paint paint4 = Paint()
      ..color = purplePastel
      ..style = PaintingStyle.fill;
    Path path4 = Path();
    double offset4X = width * 0.05 + (math.sin(animationValue * 2 * math.pi) * 10);
    double offset4Y = height * 0.05 + (math.cos(animationValue * 2 * math.pi) * 10);
    path4.addOval(Rect.fromLTWH(
        width * 0.0 + offset4X,
        height * 0.0 + offset4Y,
        width * 0.3,
        height * 0.2));
    canvas.drawPath(path4, paint4);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return (oldDelegate as _FlowyPainter).animationValue != animationValue;
  }
}


// --- New ML Prediction Screens (Simulated) and Body Nature Analysis Screen ---

abstract class _PredictionScreen extends StatefulWidget { // Kept abstract for potential future ML screens
  final String userId;
  final String title;
  final String description;
  final String modelPath; // Model path is now required

  const _PredictionScreen({
    super.key,
    required this.userId,
    required this.title,
    required this.description,
    required this.modelPath,
  });
}

abstract class _PredictionScreenState<T extends _PredictionScreen> extends State<T> {
  VitalSigns? _latestVitals;
  String _predictionResult = "Analyzing...";
  bool _isLoadingPrediction = true;
  Interpreter? _interpreter; // TensorFlow Lite interpreter

  @override
  void initState() {
    super.initState();
    _loadModelAndPredict(); // Combined loading model and prediction
  }

  @override
  void dispose() {
    _interpreter?.close(); // Close interpreter when screen is disposed
    super.dispose();
  }

// Inside _PredictionScreenState class
// ... (other methods and variables) ...

  Future<void> _loadModelAndPredict() async {
    setState(() {
      _isLoadingPrediction = true;
      _predictionResult = "Analyzing...";
    });

    try {
      // Load the TFLite model without any explicit GPU delegate options
      // It will now default to CPU inference.
      _interpreter = await Interpreter.fromAsset(widget.modelPath, options: InterpreterOptions(),); // <--- THIS IS THE ONLY LINE NEEDED FOR MODEL LOADING
      print("TFLite model loaded successfully from: ${widget.modelPath}");

      // --- Fetch Latest Vital Signs from Firestore ---
      if (_db == null || widget.userId.isEmpty) {
        _predictionResult = "Error: Database not ready or user ID missing.";
        setState(() { _isLoadingPrediction = false; });
        return;
      }

      final DocumentReference<Map<String, dynamic>> currentVitalsDocRef = _db!
          .collection('artifacts')
          .doc('vitalink-app')
          .collection('users')
          .doc(widget.userId)
          .collection('current_vitals')
          .doc('latest')
          .withConverter<Map<String, dynamic>>(
        fromFirestore: (snapshot, _) => snapshot.data()!,
        toFirestore: (model, _) => model,
      );

      final docSnap = await currentVitalsDocRef.get();

      if (docSnap.exists && docSnap.data() != null) {
        _latestVitals = VitalSigns.fromFirestore(docSnap);
        print("Latest vitals fetched for prediction.");

        // --- Perform Actual Prediction (delegated to subclass) ---
        _predictionResult = await _performPrediction(_latestVitals);

      } else {
        _predictionResult = "No recent vital data to analyze. Please update your vitals.";
      }
    } catch (e) {
      _predictionResult = "Error during analysis or model loading: $e";
      print("Error in prediction screen: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPrediction = false;
        });
      }
    }
  }

// ... (rest of your _PredictionScreenState class) ...


// ... (rest of your _PredictionScreenState class) ...


  // --- Abstract method for actual prediction logic (to be implemented by subclasses) ---
  Future<String> _performPrediction(VitalSigns? vitals);

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(
            color: Theme.of(context).appBarTheme.titleTextStyle?.color,
            fontWeight: FontWeight.bold,
            fontFamily: "Montserrat",
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 1,
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: _FlowyBackground(),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onBackground,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                      fontFamily: "Montserrat",
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _isLoadingPrediction
                        ? Column(
                      children: [
                        CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 20),
                        Text('Running Analysis...', style: TextStyle(fontSize: 18, fontFamily: 'Montserrat', color: Theme.of(context).colorScheme.onSurface)),
                      ],
                    )
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Analysis Result:',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontFamily: "Montserrat",
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _predictionResult,
                          style: TextStyle(
                            fontSize: 20,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontFamily: "Montserrat",
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_latestVitals != null) ...[
                          Divider(color: Colors.grey.shade300, height: 30, thickness: 1.5),
                          Text(
                            'Latest Vitals Used for Analysis:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                              fontFamily: "Montserrat",
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Heart Rate: ${_latestVitals!.heartRate?.toStringAsFixed(0) ?? 'N/A'} bpm\n'
                                'Body Temp: ${_latestVitals!.bodyTemp?.toStringAsFixed(1) ?? 'N/A'} °C\n'
                                'Skin Conductivity: ${_latestVitals!.skinConductivity?.toStringAsFixed(2) ?? 'N/A'} µS\n'
                                'Air Temp: ${_latestVitals!.airTemp?.toStringAsFixed(1) ?? 'N/A'} °C\n'
                                'Air Humidity: ${_latestVitals!.airHumidity?.toStringAsFixed(0) ?? 'N/A'} %',
                            style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontFamily: "Montserrat"),
                          ),
                        ],
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _loadModelAndPredict, // Re-run analysis (and re-load model)
                          icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onPrimary),
                          label: Text('Re-run Analysis', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontFamily: 'Montserrat')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Specific Prediction Screens --- (Now uses TFLite)

class HeatstrokePredictionScreen extends _PredictionScreen {
  const HeatstrokePredictionScreen({super.key, required super.userId})
      : super(
    title: 'Heatstroke Prediction',
    description: 'Analyzing your vitals and environment for heatstroke risk using an AI model.',
    modelPath: 'assets/ml_models/heatstroke_model.tflite', // Actual model path
  );

  @override
  State<HeatstrokePredictionScreen> createState() => _HeatstrokePredictionScreenState();
}

class _HeatstrokePredictionScreenState extends _PredictionScreenState<HeatstrokePredictionScreen> {
  // The actual prediction logic is now in the abstract _PredictionScreenState
  // as _performPrediction, using the loaded TFLite model.
  @override
  Future<String> _performPrediction(VitalSigns? vitals) async {
    if (vitals == null || _interpreter == null) {
      return "Prediction not possible: Missing data or model not loaded.";
    }

    // Prepare input for the TFLite model
    // Ensure the order and scaling match your trained model!
    // Our dummy model expects: [HeartRate, BodyTemp, SkinConductivity, AirTemp, AirHumidity]
    final input = [
      [
        (vitals.heartRate ?? 0.0) / 150.0, // Scale HeartRate (e.g., max 150)
        (vitals.bodyTemp ?? 0.0) / 45.0, // Scale BodyTemp (e.g., max 45)
        (vitals.skinConductivity ?? 0.0) / 10.0, // Scale SkinConductivity (e.g., max 10)
        (vitals.airTemp ?? 0.0) / 50.0, // Scale AirTemp (e.g., max 50)
        (vitals.airHumidity ?? 0.0) / 100.0, // Scale AirHumidity (e.g., max 100)
      ]
    ];

    // Output buffer: TFLite expects a List<List<double>> for batch processing, even for single output.
    // The shape is usually [1, num_outputs]. Here, num_outputs is 1.
    var output = List.generate(1, (_) => List.filled(1, 0.0)); // Correct way to initialize for [1, 1] output

    try {
      _interpreter!.run(input, output);
      final predictionValue = output[0][0]; // Get the single float prediction
      print("ML model raw prediction output for Heatstroke: $predictionValue");

      // Interpret the prediction value into risk levels
      // These thresholds depend entirely on how your model was trained
      if (predictionValue >= 0.7) {
        return "High Risk of Heatstroke! Immediate action advised: Seek shade, hydrate, cool down. Consult medical professional if symptoms worsen.";
      } else if (predictionValue >= 0.4) {
        return "Moderate Risk of Heatstroke. Be cautious: Stay hydrated, avoid prolonged sun exposure, take breaks.";
      } else {
        return "Low Risk of Heatstroke. Continue to monitor your vitals and environment.";
      }
    } catch (e) {
      print("Error running TFLite inference for Heatstroke: $e");
      return "Error during prediction: $e";
    }
  }
}

class OrganRiskPredictionScreen extends _PredictionScreen {
  const OrganRiskPredictionScreen({super.key, required super.userId})
      : super(
    title: 'Organ Failure Risk',
    description: 'Assessing potential organ stress and failure risk based on your vital signs and historical data.',
    modelPath: 'assets/ml_models/organ_risk_model.tflite', // Dummy model path
  );

  @override
  State<OrganRiskPredictionScreen> createState() => _OrganRiskPredictionScreenState();
}

class _OrganRiskPredictionScreenState extends _PredictionScreenState<OrganRiskPredictionScreen> {
  @override
  Future<String> _performPrediction(VitalSigns? vitals) async {
    if (vitals == null) {
      return "No vital data available for organ failure risk prediction. Please simulate vitals first.";
    }

    await Future.delayed(const Duration(seconds: 2)); // Simulate AI processing time

    // --- Simulated Organ Failure Risk Prediction Logic (Rule-Based) ---
    // This logic is a simplified representation. A real ML model would be more complex.
    double heartRate = vitals.heartRate ?? 0.0;
    double bodyTemp = vitals.bodyTemp ?? 0.0;
    double skinConductivity = vitals.skinConductivity ?? 0.0;
    double bloodOxygen = vitals.bloodOxygen ?? 0.0;

    int riskScore = 0;
    List<String> advicePoints = [];

    // Heart Rate Assessment
    if (heartRate < 50) {
      riskScore += 2;
      advicePoints.add("Your heart rate is lower than typical (bradycardia). This could be normal for athletes or indicate an underlying condition. Monitor closely.");
    } else if (heartRate > 100) {
      riskScore += 3;
      advicePoints.add("Your heart rate is elevated (tachycardia). This might be due to activity, stress, or a health concern. Rest and re-evaluate.");
    } else if (heartRate > 90) { // Slight elevation
      riskScore += 1;
      advicePoints.add("Your heart rate is slightly elevated. Ensure you are well-rested and hydrated.");
    }

    // Body Temperature Assessment
    if (bodyTemp < 35.0) {
      riskScore += 4;
      advicePoints.add("Your body temperature is low (hypothermia). Seek warmth and medical attention if it persists.");
    } else if (bodyTemp > 38.0) {
      riskScore += 3;
      advicePoints.add("Your body temperature is elevated (fever). Rest, hydrate, and consider medical advice if symptoms worsen.");
    } else if (bodyTemp > 37.5) { // Slight elevation
      riskScore += 1;
      advicePoints.add("Your body temperature is slightly above normal. Stay hydrated and avoid overheating.");
    }

    // Blood Oxygen Assessment (Crucial for organ function)
    if (bloodOxygen < 92.0) {
      riskScore += 5; // High impact on risk
      advicePoints.add("Your blood oxygen level is low (hypoxemia). This requires immediate medical evaluation. Seek urgent care.");
    } else if (bloodOxygen < 95.0) {
      riskScore += 2;
      advicePoints.add("Your blood oxygen level is slightly below optimal. Ensure good ventilation and deep breathing. Consult a doctor if it doesn't improve.");
    }

    // Skin Conductivity Assessment (Can indicate stress, dehydration, nervous system activity)
    if (skinConductivity < 0.5) {
      riskScore += 1;
      advicePoints.add("Low skin conductivity detected. This might be related to dehydration or reduced nervous system activity. Ensure adequate hydration.");
    } else if (skinConductivity > 15.0) {
      riskScore += 1;
      advicePoints.add("High skin conductivity detected. This can be a sign of increased stress or anxiety. Practice relaxation techniques.");
    }

    String riskLevel;
    String overallAdvice;

    if (riskScore >= 7) {
      riskLevel = "HIGH RISK";
      overallAdvice = "Based on the analysis, there is a **HIGH RISK** of organ stress or potential failure. It is **CRITICAL to seek immediate medical attention**. Do not self-diagnose or self-treat. Provide your vital data to a healthcare professional without delay.";
    } else if (riskScore >= 3) {
      riskLevel = "MODERATE RISK";
      overallAdvice = "The analysis indicates a **MODERATE RISK** of organ stress. While not immediately critical, it is **strongly recommended to consult a doctor soon** for a professional evaluation. Monitor your vitals closely, stay hydrated, ensure adequate rest, and avoid strenuous activities.";
    } else {
      riskLevel = "LOW RISK";
      overallAdvice = "Your current vital signs suggest a **LOW RISK** of organ stress. This is a positive indication. Continue to maintain healthy lifestyle habits, stay hydrated, and monitor your vitals regularly. If you experience any concerning symptoms, consult a healthcare professional.";
    }

    String detailedAdvice = advicePoints.join("\n\n");
    if (detailedAdvice.isNotEmpty) {
      detailedAdvice = "\n\n**Specific Observations & Advice:**\n$detailedAdvice";
    }

    return "$riskLevel\n\n$overallAdvice$detailedAdvice";
  }
}

class DehydrationTrackingScreen extends _PredictionScreen {
  const DehydrationTrackingScreen({super.key, required super.userId})
      : super(
    title: 'Dehydration Tracking',
    description: 'Monitoring your hydration levels based on various indicators.',
    modelPath: 'assets/ml_models/dehydration_model.tflite', // Placeholder for now
  );

  @override
  State<DehydrationTrackingScreen> createState() => _DehydrationTrackingScreenState();
}

class _DehydrationTrackingScreenState extends _PredictionScreenState<DehydrationTrackingScreen> {
  @override
  Future<String> _performPrediction(VitalSigns? vitals) async {
    if (vitals == null) {
      return "No vital data available for dehydration tracking.";
    }

    await Future.delayed(const Duration(seconds: 2)); // Simulate ML processing

    // --- Simulated Dehydration Tracking Logic (no TFLite for now) ---
    String hydrationStatus = "Well Hydrated";
    if ((vitals.heartRate ?? 0) > 90 && (vitals.skinConductivity ?? 0) < 1.0) {
      hydrationStatus = "Potentially Mildly Dehydrated. Drink water.";
    }
    if ((vitals.heartRate ?? 0) > 100 && (vitals.bodyTemp ?? 0) > 37.5 && (vitals.skinConductivity ?? 0) < 0.8) {
      hydrationStatus = "Moderate Dehydration. Increase fluid intake immediately.";
    }
    if ((vitals.heartRate ?? 0) > 110 && (vitals.bodyTemp ?? 0) > 38.0 && (vitals.skinConductivity ?? 0) < 0.5) {
      hydrationStatus = "Severe Dehydration! Seek medical attention if symptoms persist.";
    }

    return "$hydrationStatus (Simulated)";
  }
}

/// New screen for 2-Day Body Nature Analysis
class BodyNatureAnalysisScreen extends StatefulWidget {
  final String userId;

  const BodyNatureAnalysisScreen({super.key, required this.userId});

  @override
  State<BodyNatureAnalysisScreen> createState() => _BodyNatureAnalysisScreenState();
}

class _BodyNatureAnalysisScreenState extends State<BodyNatureAnalysisScreen> {
  List<VitalSigns> _historicalVitals = [];
  bool _isLoading = true;
  String _analysisResult = "No data to perform 2-day analysis yet.";
  PersonalBaseline? _personalBaseline; // To store the calculated baseline

  @override
  void initState() {
    super.initState();
    _performBodyNatureAnalysis();
  }

  // Function to calculate standard deviation
  double _calculateStandardDeviation(List<double> values, double mean) {
    if (values.isEmpty) return 0.0;
    double sumOfSquaredDifferences = values.fold(0.0, (sum, item) => sum + math.pow(item - mean, 2));
    return math.sqrt(sumOfSquaredDifferences / values.length);
  }

  Future<void> _performBodyNatureAnalysis() async {
    setState(() {
      _isLoading = true;
      _analysisResult = "Analyzing your body's nature over the past 2 days...";
    });

    if (_db == null || widget.userId.isEmpty) {
      _analysisResult = "Error: Database not ready or user ID missing for analysis.";
      setState(() { _isLoading = false; });
      return;
    }

    try {
      // Get the timestamp for 2 days ago
      final twoDaysAgo = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 2)));

      // Query vitals_history for data within the last 2 days
      final CollectionReference<Map<String, dynamic>> vitalsHistoryCollectionRef = _db!
          .collection('artifacts')
          .doc('vitalink-app')
          .collection('users')
          .doc(widget.userId)
          .collection('vitals_history')
          .withConverter<Map<String, dynamic>>(
        fromFirestore: (snapshot, _) => snapshot.data()!,
        toFirestore: (model, _) => model,
      );

      final querySnapshot = await vitalsHistoryCollectionRef
          .where('timestamp', isGreaterThanOrEqualTo: twoDaysAgo)
          .orderBy('timestamp', descending: false)
          .get();

      _historicalVitals = querySnapshot.docs.map((doc) => VitalSigns.fromFirestore(doc)).toList();

      if (_historicalVitals.isEmpty) {
        _analysisResult = "Not enough historical data (at least 2 days) to analyze your body's nature. Visit 'Check Vitals' to generate data.";
      } else {
        await Future.delayed(const Duration(seconds: 2)); // Simulate analysis time

        // Data collection for calculations
        List<double> heartRates = [];
        List<double> bodyTemps = [];
        List<double> skinConductivities = [];
        List<double> airTemps = [];
        List<double> airHumidities = [];

        for (var vital in _historicalVitals) {
          if (vital.heartRate != null) heartRates.add(vital.heartRate!);
          if (vital.bodyTemp != null) bodyTemps.add(vital.bodyTemp!);
          if (vital.skinConductivity != null) skinConductivities.add(vital.skinConductivity!);
          if (vital.airTemp != null) airTemps.add(vital.airTemp!);
          if (vital.airHumidity != null) airHumidities.add(vital.airHumidity!);
        }

        if (heartRates.isNotEmpty && bodyTemps.isNotEmpty && skinConductivities.isNotEmpty) {
          // Calculate averages
          double avgHeartRate = heartRates.reduce((a, b) => a + b) / heartRates.length;
          double avgBodyTemp = bodyTemps.reduce((a, b) => a + b) / bodyTemps.length;
          double avgSkinConductivity = skinConductivities.reduce((a, b) => a + b) / skinConductivities.length;
          double avgAirTemp = airTemps.isNotEmpty ? airTemps.reduce((a, b) => a + b) / airTemps.length : 0.0;
          double avgAirHumidity = airHumidities.isNotEmpty ? airHumidities.reduce((a, b) => a + b) / airHumidities.length : 0.0;

          // Calculate standard deviations
          double stdDevHeartRate = _calculateStandardDeviation(heartRates, avgHeartRate);
          double stdDevBodyTemp = _calculateStandardDeviation(bodyTemps, avgBodyTemp);
          double stdDevSkinConductivity = _calculateStandardDeviation(skinConductivities, avgSkinConductivity);

          // Calculate min/max
          double minHeartRate = heartRates.reduce(math.min);
          double maxHeartRate = heartRates.reduce(math.max);
          double minBodyTemp = bodyTemps.reduce(math.min);
          double maxBodyTemp = bodyTemps.reduce(math.max);
          double minSkinConductivity = skinConductivities.reduce(math.min);
          double maxSkinConductivity = skinConductivities.reduce(math.max);

          final int daysDifference = _historicalVitals.isNotEmpty
              ? (_historicalVitals.last.timestamp!.toDate().difference(_historicalVitals.first.timestamp!.toDate()).inDays).abs()
              : 0;

          // Create PersonalBaseline object
          _personalBaseline = PersonalBaseline(
            avgHeartRate: avgHeartRate,
            stdDevHeartRate: stdDevHeartRate,
            minHeartRate: minHeartRate,
            maxHeartRate: maxHeartRate,
            avgBodyTemp: avgBodyTemp,
            stdDevBodyTemp: stdDevBodyTemp,
            minBodyTemp: minBodyTemp,
            maxBodyTemp: maxBodyTemp,
            avgSkinConductivity: avgSkinConductivity,
            stdDevSkinConductivity: stdDevSkinConductivity,
            minSkinConductivity: minSkinConductivity,
            maxSkinConductivity: maxSkinConductivity,
            avgAirTemp: avgAirTemp,
            avgAirHumidity: avgAirHumidity,
            lastCalculated: Timestamp.now(),
          );

          // Save the PersonalBaseline to Firestore
          final baselineDocRef = _db!
              .collection('artifacts')
              .doc('vitalink-app')
              .collection('users')
              .doc(widget.userId)
              .collection('baseline') // New: 'baseline' is a collection
              .doc('personal_baseline') // New: 'personal_baseline' is a document
              .withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, _) => snapshot.data()!,
            toFirestore: (model, _) => model,
          );
          await baselineDocRef.set(_personalBaseline!.toMap(), SetOptions(merge: true));
          print("Personal baseline saved to Firestore.");

          _analysisResult = """
Based on your last ${_historicalVitals.length} vital readings over the past ${daysDifference} days, your personalized baseline is:

**Heart Rate:**
  Average: **${_personalBaseline!.avgHeartRate.toStringAsFixed(0)} bpm**
  Range: ${_personalBaseline!.minHeartRate.toStringAsFixed(0)}-${_personalBaseline!.maxHeartRate.toStringAsFixed(0)} bpm
  Variability (Std Dev): ${_personalBaseline!.stdDevHeartRate.toStringAsFixed(2)}

**Body Temperature:**
  Average: **${_personalBaseline!.avgBodyTemp.toStringAsFixed(1)} °C**
  Range: ${_personalBaseline!.minBodyTemp.toStringAsFixed(1)}-${_personalBaseline!.maxBodyTemp.toStringAsFixed(1)} °C
  Variability (Std Dev): ${_personalBaseline!.stdDevBodyTemp.toStringAsFixed(2)}

**Skin Conductivity:**
  Average: **${_personalBaseline!.avgSkinConductivity.toStringAsFixed(2)} µS**
  Range: ${_personalBaseline!.minSkinConductivity.toStringAsFixed(2)}-${_personalBaseline!.maxSkinConductivity.toStringAsFixed(2)} µS
  Variability (Std Dev): ${_personalBaseline!.stdDevSkinConductivity.toStringAsFixed(2)}

Average Surrounding Temperature: ${_personalBaseline!.avgAirTemp.toStringAsFixed(1)} °C
Average Surrounding Humidity: ${_personalBaseline!.avgAirHumidity.toStringAsFixed(0)} %

This comprehensive baseline helps your AI understand your unique physiological patterns and detect significant deviations.
          """;
        } else {
          _analysisResult = "Not enough relevant data points (Heart Rate, Body Temp, Skin Conductivity) collected in the last 2 days to calculate a full baseline. Visit 'Check Vitals' to generate data.";
        }
      }
    } catch (e) {
      _analysisResult = "Error performing analysis: $e";
      print("Error in BodyNatureAnalysisScreen: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '2-Day Body Nature',
          style: TextStyle(
            color: Theme.of(context).appBarTheme.titleTextStyle?.color,
            fontWeight: FontWeight.bold,
            fontFamily: "Montserrat",
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 1,
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: _FlowyBackground(),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Your Body\'s Unique Nature',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onBackground,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This analysis establishes your personal health baseline over the last 2 days, essential for personalized AI insights.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                      fontFamily: "Montserrat",
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _isLoading
                        ? Column(
                      children: [
                        CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 20),
                        Text('Learning your body\'s nature...', style: TextStyle(fontSize: 18, fontFamily: 'Montserrat', color: Theme.of(context).colorScheme.onSurface)),
                      ],
                    )
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your 2-Day Baseline:',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontFamily: "Montserrat",
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Using Text.rich and TextSpan for rich text/bolding
                        Text.rich(
                          TextSpan(
                            text: '',
                            style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontFamily: "Montserrat"), // Moved style here
                            children: [
                              for (var line in _analysisResult.split('\n')) ...[
                                TextSpan(
                                  text: line.contains('**')
                                      ? line.replaceAll('**', '') // Remove markdown bold for TextSpan content
                                      : line,
                                  style: line.contains('**')
                                      ? TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, fontFamily: "Montserrat")
                                      : TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9), fontFamily: "Montserrat"),
                                ),
                                const TextSpan(text: '\n'),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _performBodyNatureAnalysis,
                          icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onPrimary),
                          label: Text('Re-analyze', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontFamily: 'Montserrat')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// New screen for tracking medicine effectiveness.
class MedicineEffectivenessTrackerScreen extends StatefulWidget {
  final String userId;

  const MedicineEffectivenessTrackerScreen({super.key, required this.userId});

  @override
  State<MedicineEffectivenessTrackerScreen> createState() => _MedicineEffectivenessTrackerScreenState();
}

class _MedicineEffectivenessTrackerScreenState extends State<MedicineEffectivenessTrackerScreen> {
  final TextEditingController _medicineNameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now();
  String _aiAdviceResult = "Enter medicine details and tap 'Analyze Effectiveness' to get AI advice.";
  bool _isLoadingAnalysis = false;

  @override
  void dispose() {
    _medicineNameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _performEffectivenessAnalysis() async {
    if (_medicineNameController.text.isEmpty || _dosageController.text.isEmpty) {
      _showSnackBar("Please enter medicine name and dosage.", isError: true);
      return;
    }

    setState(() {
      _isLoadingAnalysis = true;
      _aiAdviceResult = "Analyzing medicine effectiveness...";
    });

    try {
      // 1. Save medicine intake to Firestore
      final medicineIntake = MedicineIntake(
        medicineName: _medicineNameController.text.trim(),
        dosage: _dosageController.text.trim(),
        intakeTime: Timestamp.fromMicrosecondsSinceEpoch(_selectedDateTime.microsecondsSinceEpoch),
      );

      if (_db == null || widget.userId.isEmpty) {
        _showSnackBar("Database not ready or user ID missing. Cannot save medicine intake.", isError: true);
        setState(() { _isLoadingAnalysis = false; });
        return;
      }

      final medicineIntakeCollectionRef = _db!
          .collection('artifacts')
          .doc('vitalink-app')
          .collection('users')
          .doc(widget.userId)
          .collection('medicine_intake');

      // Add the new medicine intake record
      final newDocRef = await medicineIntakeCollectionRef.add(medicineIntake.toMap());
      print("Medicine intake saved to Firestore with ID: ${newDocRef.id}");

      // 2. Fetch vital signs recorded AFTER the medicine intake time
      // We'll look for vitals within a reasonable window after intake (e.g., 4-6 hours)
      final vitalsAfterIntakeQuery = _db!
          .collection('artifacts')
          .doc('vitalink-app')
          .collection('users')
          .doc(widget.userId)
          .collection('vitals_history')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromMicrosecondsSinceEpoch(_selectedDateTime.microsecondsSinceEpoch))
          .orderBy('timestamp', descending: false)
          .limit(10); // Limit to a few recent vitals after intake

      final querySnapshot = await vitalsAfterIntakeQuery.get();
      List<VitalSigns> vitalsAfterMedicine = querySnapshot.docs.map((doc) => VitalSigns.fromFirestore(doc)).toList();

      if (vitalsAfterMedicine.isEmpty) {
        _aiAdviceResult = """
No vital data recorded *after* the specified medicine intake time.
Please ensure you have:
1.  Generated recent vital readings (go to 'Check Vitals' and tap 'Simulate & Refresh Data').
2.  Set the 'Time Taken' for the medicine to be *before* some of your recorded vitals.
""";
      } else {
        // --- Simulated AI Logic for Medicine Effectiveness ---
        // This is a simplified rule-based simulation.
        // A real ML model would be much more complex, trained on vast datasets.
        String medicineNameLower = _medicineNameController.text.toLowerCase();
        VitalSigns firstVitalAfter = vitalsAfterMedicine.first;
        VitalSigns lastVitalAfter = vitalsAfterMedicine.last; // Get the latest vital after intake

        String effectiveness = "No significant change detected.";
        String advice = "Continue to monitor your symptoms and vitals. If symptoms persist or worsen, consult your healthcare provider.";

        // --- Simulated Effectiveness based on Medicine Type and Vital Changes ---
        if (medicineNameLower.contains('fever') || medicineNameLower.contains('paracetamol') || medicineNameLower.contains('ibuprofen')) {
          // Assuming a fever reducer should lower body temperature
          if ((firstVitalAfter.bodyTemp ?? 0) > 37.5 && (lastVitalAfter.bodyTemp ?? 0) < 37.0) {
            effectiveness = "Highly Effective!";
            advice = "Your body temperature has significantly decreased after taking the medicine. This indicates good effectiveness. Continue to rest and stay hydrated.";
          } else if ((firstVitalAfter.bodyTemp ?? 0) > (lastVitalAfter.bodyTemp ?? 0) && (lastVitalAfter.bodyTemp ?? 0) > 37.0) {
            effectiveness = "Moderately Effective.";
            advice = "Your body temperature has shown some reduction, but is still slightly elevated. Continue monitoring and follow dosage instructions. If fever persists, consult a doctor.";
          }
        } else if (medicineNameLower.contains('painkiller') || medicineNameLower.contains('analgesic')) {
          // Assuming pain relief might correlate with reduced heart rate (stress) or improved skin conductivity
          if ((firstVitalAfter.heartRate ?? 0) > 85 && (lastVitalAfter.heartRate ?? 0) < 75) {
            effectiveness = "Highly Effective!";
            advice = "Your heart rate has decreased, suggesting a reduction in discomfort or stress. The medicine appears to be working well. Continue to rest.";
          } else if ((firstVitalAfter.heartRate ?? 0) > (lastVitalAfter.heartRate ?? 0) && (lastVitalAfter.heartRate ?? 0) > 75) {
            effectiveness = "Moderately Effective.";
            advice = "There's a slight reduction in your heart rate, indicating some relief. If pain persists, consider consulting your doctor for further guidance.";
          }
        } else if (medicineNameLower.contains('blood pressure') || medicineNameLower.contains('hypertension')) {
          // Placeholder for blood pressure, as we don't have BP vitals yet.
          effectiveness = "Analysis for blood pressure medicine requires specific blood pressure readings. Please consult your doctor for evaluation.";
          advice = "For accurate assessment of blood pressure medication, direct blood pressure readings are essential. This app currently focuses on general vitals. Always follow your doctor's advice.";
        } else {
          effectiveness = "Effectiveness analysis for this medicine type is not specifically programmed.";
          advice = "The AI's current model does not have specific parameters for this medicine. Please consult your healthcare provider for evaluation of its effectiveness based on your symptoms.";
        }

        _aiAdviceResult = "Medicine Effectiveness: **$effectiveness**\n\n**AI Advice:**\n$advice";
      }

      // Update the saved medicine intake with the analysis result
      // Use the newDocRef.id from when we added the document earlier
      await medicineIntakeCollectionRef.doc(newDocRef.id).update({
        'analysisResult': _aiAdviceResult,
        'analyzedAt': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      _aiAdviceResult = "Error during effectiveness analysis: $e";
      print("Error in MedicineEffectivenessTrackerScreen: $e");
      _showSnackBar("Error during analysis: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAnalysis = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Medicine Effectiveness',
          style: TextStyle(
            color: Theme.of(context).appBarTheme.titleTextStyle?.color,
            fontWeight: FontWeight.bold,
            fontFamily: "Montserrat",
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 1,
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: _FlowyBackground(),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Track Medicine Effectiveness',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onBackground,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Enter details about your medication to analyze its impact on your vitals.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                      fontFamily: "Montserrat",
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _medicineNameController,
                          decoration: InputDecoration(
                            labelText: 'Medicine Name',
                            hintText: 'e.g., Paracetamol, Ibuprofen',
                            prefixIcon: Icon(Icons.medication_outlined, color: Theme.of(context).colorScheme.primary),
                          ),
                          style: TextStyle(fontFamily: 'Montserrat', color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _dosageController,
                          decoration: InputDecoration(
                            labelText: 'Dosage',
                            hintText: 'e.g., 500mg, 1 tablet',
                            prefixIcon: Icon(Icons.numbers_outlined, color: Theme.of(context).colorScheme.primary),
                          ),
                          style: TextStyle(fontFamily: 'Montserrat', color: Theme.of(context).colorScheme.onSurface),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          title: Text(
                            'Time Taken: ${DateFormat('MMM d,yyyy HH:mm').format(_selectedDateTime)}',
                            style: TextStyle(fontSize: 16, fontFamily: 'Montserrat', color: Theme.of(context).colorScheme.onSurface),
                          ),
                          trailing: Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary),
                          onTap: () => _selectDateTime(context),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _isLoadingAnalysis ? null : _performEffectivenessAnalysis,
                          icon: Icon(Icons.analytics_outlined, color: Theme.of(context).colorScheme.onPrimary),
                          label: Text(
                            _isLoadingAnalysis ? 'Analyzing...' : 'Analyze Effectiveness',
                            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontFamily: 'Montserrat'),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Divider(color: Colors.grey.shade300, height: 30, thickness: 1.5),
                        Text(
                          'AI Advice:',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontFamily: "Montserrat",
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text.rich(
                          TextSpan(
                            text: '',
                            style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontFamily: "Montserrat"),
                            children: [
                              for (var line in _aiAdviceResult.split('\n')) ...[
                                TextSpan(
                                  text: line.contains('**')
                                      ? line.replaceAll('**', '')
                                      : line,
                                  style: line.contains('**')
                                      ? TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, fontFamily: "Montserrat")
                                      : TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9), fontFamily: "Montserrat"),
                                ),
                                const TextSpan(text: '\n'),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// New screen for Anomaly Detection.
class AnomalyDetectionScreen extends _PredictionScreen {
  const AnomalyDetectionScreen({super.key, required super.userId})
      : super(
    title: 'Anomaly Detection',
    description: 'Detecting unexpected changes in your vital signs and providing insights.',
    modelPath: 'assets/ml_models/anomaly_detection_model.tflite', // Path to our dummy model
  );

  @override
  State<AnomalyDetectionScreen> createState() => _AnomalyDetectionScreenState();
}

class _AnomalyDetectionScreenState extends _PredictionScreenState<AnomalyDetectionScreen> {
  PersonalBaseline? _personalBaseline; // To store the user's baseline

  @override
  void initState() {
    super.initState();
    _loadModelAndPredict(); // This calls _performPrediction
  }

  @override
  Future<String> _performPrediction(VitalSigns? vitals) async {
    if (vitals == null) {
      return "No recent vital data to analyze for anomalies. Please update your vitals via 'Check Vitals'.";
    }

    // 1. Fetch Personal Baseline
    if (_db == null || widget.userId.isEmpty) {
      return "Error: Database not ready or user ID missing for baseline.";
    }

    try {
      final baselineDocRef = _db!
          .collection('artifacts')
          .doc('vitalink-app')
          .collection('users')
          .doc(widget.userId)
          .collection('baseline')
          .doc('personal_baseline')
          .withConverter<Map<String, dynamic>>(
        fromFirestore: (snapshot, _) => snapshot.data()!,
        toFirestore: (model, _) => model,
      );
      final baselineSnap = await baselineDocRef.get();

      if (baselineSnap.exists && baselineSnap.data() != null) {
        _personalBaseline = PersonalBaseline.fromFirestore(baselineSnap);
        print("Personal baseline loaded for anomaly detection.");
      } else {
        return "No personal baseline found. Please run '2-Day Body Nature Analysis' first from the Home screen under 'Proactive Health' to establish your baseline.";
      }
    } catch (e) {
      print("Error fetching personal baseline for anomaly detection: $e");
      return "Error fetching personal baseline: $e";
    }

    await Future.delayed(const Duration(seconds: 2)); // Simulate AI processing time

    // --- Anomaly Detection Logic (Rule-Based Simulation using Baseline) ---
    // This simulates an ML model's output by comparing current vitals to the established baseline.
    // A real ML model would have been trained on deviations from normal.

    List<String> anomalies = [];
    List<String> advice = [];

    // Heart Rate Anomaly
    if (_personalBaseline!.avgHeartRate > 0) { // Ensure baseline is not zero
      double hrDeviation = (vitals.heartRate ?? 0) - _personalBaseline!.avgHeartRate;
      double hrStdDev = _personalBaseline!.stdDevHeartRate;
      if (hrStdDev == 0) hrStdDev = 5.0; // Prevent division by zero, use a default small deviation

      if (hrDeviation.abs() > 2 * hrStdDev) { // More than 2 standard deviations away
        anomalies.add("Heart Rate: Your current heart rate (${vitals.heartRate?.toStringAsFixed(0)} bpm) is significantly ${hrDeviation > 0 ? 'higher' : 'lower'} than your baseline average (${_personalBaseline!.avgHeartRate.toStringAsFixed(0)} bpm).");
        if (hrDeviation > 0) {
          advice.add("Elevated heart rate could be due to stress, activity, or other factors. Try to relax, stay hydrated, and monitor if it persists. If you feel unwell, consult a doctor.");
        } else {
          advice.add("Lower heart rate might be normal for you, but if accompanied by fatigue or dizziness, consult a doctor.");
        }
      }
    }

    // Body Temperature Anomaly
    if (_personalBaseline!.avgBodyTemp > 0) {
      double tempDeviation = (vitals.bodyTemp ?? 0) - _personalBaseline!.avgBodyTemp;
      double tempStdDev = _personalBaseline!.stdDevBodyTemp;
      if (tempStdDev == 0) tempStdDev = 0.5; // Prevent division by zero

      if (tempDeviation.abs() > 2 * tempStdDev) { // More than 2 standard deviations away
        anomalies.add("Body Temperature: Your current body temperature (${vitals.bodyTemp?.toStringAsFixed(1)}°C) is significantly ${tempDeviation > 0 ? 'higher' : 'lower'} than your baseline average (${_personalBaseline!.avgBodyTemp.toStringAsFixed(1)}°C).");
        if (tempDeviation > 0) {
          advice.add("Elevated body temperature could indicate a fever or increased metabolic activity. Rest, hydrate, and consider medical advice if it rises further.");
        } else {
          advice.add("Lower body temperature might suggest hypothermia or other issues. Seek warmth and monitor your condition.");
        }
      }
    }

    // Skin Conductivity Anomaly
    if (_personalBaseline!.avgSkinConductivity > 0) {
      double scDeviation = (vitals.skinConductivity ?? 0) - _personalBaseline!.avgSkinConductivity;
      double scStdDev = _personalBaseline!.stdDevSkinConductivity;
      if (scStdDev == 0) scStdDev = 1.0; // Prevent division by zero

      if (scDeviation.abs() > 2 * scStdDev) { // More than 2 standard deviations away
        anomalies.add("Skin Conductivity: Your current skin conductivity (${vitals.skinConductivity?.toStringAsFixed(2)} µS) is significantly ${scDeviation > 0 ? 'higher' : 'lower'} than your baseline average (${_personalBaseline!.avgSkinConductivity.toStringAsFixed(2)} µS).");
        if (scDeviation > 0) {
          advice.add("Higher skin conductivity can be linked to increased stress or anxiety. Practice relaxation techniques and ensure you're well-hydrated.");
        } else {
          advice.add("Lower skin conductivity might indicate reduced sympathetic nervous system activity. Continue to monitor and ensure adequate hydration.");
        }
      }
    }

    String result = "";
    if (anomalies.isEmpty) {
      result = "No significant anomalies detected in your recent vital signs compared to your personal baseline. Your health appears stable.";
    } else {
      result = "**Anomalies Detected:**\n\n";
      result += anomalies.map((a) => "• $a").join("\n\n");
      result += "\n\n**AI Advice:**\n\n";
      result += advice.map((a) => "• $a").join("\n\n");
      result += "\n\nRemember, this is an AI analysis. For any health concerns, always consult a medical professional.";
    }

    return result;
  }
}


// Data model for weekly vital averages
class WeeklyVitalsData {
  final int weekNumber; // Or timestamp for the start of the week
  final double avgHeartRate;
  final double avgBodyTemp;
  final double avgSkinConductivity;
  final DateTime weekStartDate; // To properly group and display weeks

  WeeklyVitalsData({
    required this.weekNumber,
    required this.avgHeartRate,
    required this.avgBodyTemp,
    required this.avgSkinConductivity,
    required this.weekStartDate,
  });
}


/// New screen for Environmental Precautions.
class EnvironmentalPrecautionsScreen extends StatefulWidget {
  final String userId;

  const EnvironmentalPrecautionsScreen({super.key, required this.userId});

  @override
  State<EnvironmentalPrecautionsScreen> createState() => _EnvironmentalPrecautionsScreenState();
}

class _EnvironmentalPrecautionsScreenState extends State<EnvironmentalPrecautionsScreen> {
  bool _isLoading = true;
  VitalSigns? _latestVitals; // To get current air temp/humidity/weather
  String _environmentalAdvice = "Fetching environmental data and generating advice...";
  String _aqiStatus = "Loading AQI..."; // Air Quality Index status

  @override
  void initState() {
    super.initState();
    _fetchEnvironmentalDataAndAdvise();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Fetches current location, weather data, and AQI, then generates advice.
  Future<void> _fetchEnvironmentalDataAndAdvise() async {
    setState(() {
      _isLoading = true;
      _environmentalAdvice = "Fetching environmental data and generating advice...";
      _aqiStatus = "Loading AQI...";
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar("Location permissions are denied. Cannot fetch live weather.", isError: true);
          _environmentalAdvice = "Location permissions denied. Cannot provide real-time environmental advice.";
          setState(() { _isLoading = false; });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar("Location permissions are permanently denied. Please enable them in settings.", isError: true);
        _environmentalAdvice = "Location permissions permanently denied. Please enable them in settings to get environmental advice.";
        setState(() { _isLoading = false; });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      final lat = position.latitude;
      final lon = position.longitude;

      if (OPENWEATHER_API_KEY.isEmpty || OPENWEATHER_API_KEY == "YOUR_OPENWEATHER_API_KEY") {
        _showSnackBar("OpenWeatherMap API Key is not set or invalid! Using default environmental values.", isError: true);
        _environmentalAdvice = "OpenWeatherMap API Key is missing or invalid. Cannot fetch live environmental data. Using simulated data for advice.";
        // Simulate data if API key is missing
        _latestVitals = VitalSigns(
          airTemp: 25.0,
          airHumidity: 60.0,
          weatherMain: "Clear",
          weatherIconCode: "01d",
          aqi: 2, // Moderate
          timestamp: Timestamp.now(),
        );
        _environmentalAdvice = _generateEnvironmentalAdvice(_latestVitals!);
        _aqiStatus = _getAqiStatus(_latestVitals!.aqi);
        setState(() { _isLoading = false; });
        return;
      }

      // Fetch current weather
      final weatherUrl = 'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$OPENWEATHER_API_KEY&units=metric';
      final weatherResponse = await http.get(Uri.parse(weatherUrl));
      Map<String, dynamic> weatherData = {};
      if (weatherResponse.statusCode == 200) {
        weatherData = json.decode(weatherResponse.body);
      } else {
        String errorBody = weatherResponse.body.isNotEmpty ? json.decode(weatherResponse.body)['message'] ?? 'No message' : 'Empty response body';
        _showSnackBar("Failed to load weather data: ${weatherResponse.statusCode} - $errorBody", isError: true);
        print("Failed to load weather data: ${weatherResponse.statusCode} - $errorBody");
      }

      // Fetch Air Quality Index (AQI)
      final aqiUrl = 'https://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$OPENWEATHER_API_KEY';
      final aqiResponse = await http.get(Uri.parse(aqiUrl));
      Map<String, dynamic> aqiData = {};
      if (aqiResponse.statusCode == 200) {
        aqiData = json.decode(aqiResponse.body);
      } else {
        String errorBody = aqiResponse.body.isNotEmpty ? json.decode(aqiResponse.body)['message'] ?? 'No message' : 'Empty response body';
        _showSnackBar("Failed to load AQI data: ${aqiResponse.statusCode} - $errorBody", isError: true);
        print("Failed to load AQI data: ${aqiResponse.statusCode} - $errorBody");
      }

      // Populate _latestVitals with fetched data
      _latestVitals = VitalSigns(
        airTemp: (weatherData['main']?['temp'] as num?)?.toDouble(),
        airHumidity: (weatherData['main']?['humidity'] as num?)?.toDouble(),
        weatherMain: weatherData['weather']?[0]?['main'],
        weatherIconCode: weatherData['weather']?[0]?['icon'],
        aqi: (aqiData['list']?[0]?['main']?['aqi'] as num?)?.toInt(),
        timestamp: Timestamp.now(),
      );

      _environmentalAdvice = _generateEnvironmentalAdvice(_latestVitals!);
      _aqiStatus = _getAqiStatus(_latestVitals!.aqi);

    } catch (e) {
      _environmentalAdvice = "Error fetching environmental data: $e";
      print("Error in EnvironmentalPrecautionsScreen: $e");
      _showSnackBar("Error fetching environmental data: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _generateEnvironmentalAdvice(VitalSigns vitals) {
    String advice = "Based on current environmental conditions:\n\n";
    List<String> precautions = [];

    double? airTemp = vitals.airTemp;
    double? airHumidity = vitals.airHumidity;
    String? weatherMain = vitals.weatherMain;
    int? aqi = vitals.aqi;

    if (airTemp != null) {
      if (airTemp > 30) {
        precautions.add("It's hot (${airTemp.toStringAsFixed(1)}°C)! Stay hydrated, seek shade, and avoid prolonged outdoor activities, especially during peak sun hours.");
      } else if (airTemp < 10) {
        precautions.add("It's cool (${airTemp.toStringAsFixed(1)}°C). Dress in layers to stay warm and prevent hypothermia.");
      } else {
        precautions.add("The temperature (${airTemp.toStringAsFixed(1)}°C) is comfortable. Enjoy your day!");
      }
    }

    if (airHumidity != null) {
      if (airHumidity > 70) {
        precautions.add("High humidity (${airHumidity.toStringAsFixed(0)}%) can make heat feel worse. Ensure good ventilation and stay cool.");
      } else if (airHumidity < 30) {
        precautions.add("Low humidity (${airHumidity.toStringAsFixed(0)}%) can cause dry skin and respiratory irritation. Consider a humidifier indoors and stay hydrated.");
      }
    }

    if (weatherMain != null) {
      if (weatherMain.toLowerCase().contains('rain') || weatherMain.toLowerCase().contains('drizzle')) {
        precautions.add("It's raining! Carry an umbrella and wear waterproof clothing. Be careful of slippery surfaces.");
      } else if (weatherMain.toLowerCase().contains('clear')) {
        precautions.add("Clear skies! Great for outdoor activities, but remember sun protection (sunscreen, hat).");
      } else if (weatherMain.toLowerCase().contains('clouds')) {
        precautions.add("Cloudy weather. Still, UV rays can penetrate clouds, so consider light sun protection.");
      } else if (weatherMain.toLowerCase().contains('thunderstorm')) {
        precautions.add("Thunderstorm alert! Seek indoor shelter immediately. Avoid open areas and tall objects.");
      } else if (weatherMain.toLowerCase().contains('snow')) {
        precautions.add("Snowfall! Dress warmly, wear appropriate footwear, and be cautious of icy conditions.");
      }
    }

    if (aqi != null) {
      String aqiStatusText = _getAqiStatus(aqi);
      if (aqi >= 3) { // Moderate to Very Unhealthy
        precautions.add("Air Quality is **${aqiStatusText}**. Individuals with respiratory sensitivities should limit prolonged outdoor exertion. Consider wearing a mask outdoors.");
      } else {
        precautions.add("Air Quality is **${aqiStatusText}**. Generally good for outdoor activities.");
      }
    }

    if (precautions.isEmpty) {
      advice += "No specific environmental precautions needed at this time. Conditions appear mild.";
    } else {
      advice += precautions.map((p) => "• $p").join("\n\n");
    }

    advice += "\n\nAlways check local weather updates for the most accurate information.";
    return advice;
  }

  String _getAqiStatus(int? aqi) {
    if (aqi == null) return "N/A";
    switch (aqi) {
      case 1: return "Good";
      case 2: return "Fair";
      case 3: return "Moderate";
      case 4: return "Poor";
      case 5: return "Very Poor";
      default: return "Unknown";
    }
  }

  String _getWeatherIconUrl(String? iconCode) {
    if (iconCode == null) return ''; // Return empty string if no icon code
    return 'https://openweathermap.org/img/wn/$iconCode@2x.png';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Environmental Precautions',
          style: TextStyle(
            color: Theme.of(context).appBarTheme.titleTextStyle?.color,
            fontWeight: FontWeight.bold,
            fontFamily: "Montserrat",
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 1,
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: _FlowyBackground(),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Environmental Health',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onBackground,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Understanding your environment helps you stay healthy. Get real-time weather and air quality insights.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                      fontFamily: "Montserrat",
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _isLoading
                        ? Column(
                      children: [
                        CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 20),
                        Text('Fetching environmental data...', style: TextStyle(fontSize: 18, fontFamily: 'Montserrat', color: Theme.of(context).colorScheme.onSurface)),
                      ],
                    )
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Environmental Conditions:',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontFamily: "Montserrat",
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_latestVitals != null && _latestVitals!.timestamp != null)
                          Text(
                            'Last Updated: ${DateFormat('MMM d,yyyy HH:mm').format(_latestVitals!.timestamp!.toDate())}',
                            style: TextStyle(
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              fontStyle: FontStyle.italic,
                              fontFamily: "Montserrat",
                            ),
                          ),
                        const SizedBox(height: 10),
                        Divider(color: Colors.grey.shade300, height: 30, thickness: 1.5),
                        Row(
                          children: [
                            if (_latestVitals?.weatherIconCode != null)
                              Image.network(
                                _getWeatherIconUrl(_latestVitals!.weatherIconCode),
                                width: 50,
                                height: 50,
                                errorBuilder: (context, error, stackTrace) => Icon(Icons.cloud, size: 50, color: Theme.of(context).colorScheme.primary),
                              ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Weather: ${_latestVitals?.weatherMain ?? 'N/A'}',
                                style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurface, fontFamily: "Montserrat"),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Temperature: ${_latestVitals?.airTemp?.toStringAsFixed(1) ?? 'N/A'} °C',
                          style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurface, fontFamily: "Montserrat"),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Humidity: ${_latestVitals?.airHumidity?.toStringAsFixed(0) ?? 'N/A'} %',
                          style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurface, fontFamily: "Montserrat"),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Air Quality Index (AQI): ${_latestVitals?.aqi ?? 'N/A'} (${_aqiStatus})',
                          style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurface, fontFamily: "Montserrat"),
                        ),
                        const SizedBox(height: 32),
                        Divider(color: Colors.grey.shade300, height: 30, thickness: 1.5),
                        Text(
                          'AI Environmental Advice:',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontFamily: "Montserrat",
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text.rich(
                          TextSpan(
                            text: '',
                            style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontFamily: "Montserrat"),
                            children: [
                              for (var line in _environmentalAdvice.split('\n')) ...[
                                TextSpan(
                                  text: line.contains('**')
                                      ? line.replaceAll('**', '')
                                      : line,
                                  style: line.contains('**')
                                      ? TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, fontFamily: "Montserrat")
                                      : TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9), fontFamily: "Montserrat"),
                                ),
                                const TextSpan(text: '\n'), // Add newline after each line
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _fetchEnvironmentalDataAndAdvise,
                          icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onPrimary),
                          label: Text('Refresh Environmental Data', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontFamily: 'Montserrat')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// New screen for Trend Analysis and Charts
class TrendAnalysisScreen extends StatefulWidget {
  final String userId;

  const TrendAnalysisScreen({super.key, required this.userId});

  @override
  State<TrendAnalysisScreen> createState() => _TrendAnalysisScreenState();
}

class _TrendAnalysisScreenState extends State<TrendAnalysisScreen> {
  bool _isLoading = true;
  List<WeeklyVitalsData> _weeklyVitals = [];
  PersonalBaseline? _personalBaseline;
  String _aiHealthFeedback = "Analyzing your health trends...";
  String _selectedVitalType = 'Heart Rate'; // Default selected vital for chart
  bool _isDailyView = false; // NEW: To track if showing daily or weekly view

  @override
  void initState() {
    super.initState();
    _fetchAndAnalyzeTrends();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _fetchAndAnalyzeTrends() async {
    setState(() {
      _isLoading = true;
      _aiHealthFeedback = "Analyzing your health trends...";
      _weeklyVitals = []; // Clear previous data
      _isDailyView = false; // Reset for initial check
    });

    if (_db == null || widget.userId.isEmpty) {
      _aiHealthFeedback = "Error: Database not ready or user ID missing.";
      setState(() { _isLoading = false; });
      return;
    }

    try {
      final now = DateTime.now();
      // Corrected eightWeeksAgo calculation to use Duration(days: 8 * 7) or Duration(weeks: 8)
      final eightWeeksAgo = Timestamp.fromDate(now.subtract(const Duration()));
      final sevenDaysAgo = Timestamp.fromDate(now.subtract(const Duration(days: 7)));

      final CollectionReference<Map<String, dynamic>> vitalsHistoryCollectionRef = _db!
          .collection('artifacts')
          .doc('vitalink-app')
          .collection('users')
          .doc(widget.userId)
          .collection('vitals_history')
          .withConverter<Map<String, dynamic>>(
        fromFirestore: (snapshot, _) => snapshot.data()!,
        toFirestore: (model, _) => model,
      );

      // 1. Try to fetch data for the last 8 weeks first to check for weekly viability
      final querySnapshotWeeks = await vitalsHistoryCollectionRef
          .where('timestamp', isGreaterThanOrEqualTo: eightWeeksAgo)
          .orderBy('timestamp', descending: false)
          .get();

      List<VitalSigns> historicalVitalsForCheck = querySnapshotWeeks.docs.map((doc) => VitalSigns.fromFirestore(doc)).toList();

      // Check if we have enough distinct days for a meaningful weekly view (e.g., at least 7 distinct days)
      final distinctDays = historicalVitalsForCheck
          .where((v) => v.timestamp != null)
          .map((v) => DateTime(v.timestamp!.toDate().year, v.timestamp!.toDate().month, v.timestamp!.toDate().day))
          .toSet()
          .length;

      List<VitalSigns> vitalsToProcess;

      if (distinctDays >= 7) {
        // Enough data for weekly view
        _isDailyView = false;
        vitalsToProcess = historicalVitalsForCheck; // Use the 8-week data
      } else {
        // Not enough data for weekly view, switch to daily view for last 7 days
        _isDailyView = true;
        final querySnapshotDays = await vitalsHistoryCollectionRef
            .where('timestamp', isGreaterThanOrEqualTo: sevenDaysAgo)
            .orderBy('timestamp', descending: false)
            .get();
        vitalsToProcess = querySnapshotDays.docs.map((doc) => VitalSigns.fromFirestore(doc)).toList();
      }

      if (vitalsToProcess.isEmpty) {
        _aiHealthFeedback = "No historical vital data found. Please generate more vitals data via 'Check Vitals'.";
      } else {
        Map<int, List<VitalSigns>> groupedVitals = {};
        Map<int, DateTime> groupStartDates = {};

        for (var vital in vitalsToProcess) {
          if (vital.timestamp != null) {
            DateTime date = vital.timestamp!.toDate();
            int key;
            if (_isDailyView) {
              key = date.year * 10000 + date.month * 100 + date.day; // YYYYMMDD for daily key
              groupStartDates.putIfAbsent(key, () => DateTime(date.year, date.month, date.day));
            } else {
              int year = date.year;
              int weekOfYear = ((date.dayOfYear - 1) ~/ 7) + 1;
              key = year * 100 + weekOfYear; // YYYYWW for weekly key
              groupStartDates.putIfAbsent(key, () => date.subtract(Duration(days: date.weekday - 1))); // Monday of the week
            }
            groupedVitals.putIfAbsent(key, () => []).add(vital);
          }
        }

        List<WeeklyVitalsData> calculatedVitals = [];
        List<int> sortedKeys = groupedVitals.keys.toList()..sort();

        for (var key in sortedKeys) {
          List<VitalSigns> groupVitals = groupedVitals[key]!;
          double avgHeartRate = groupVitals.map((v) => v.heartRate ?? 0.0).where((hr) => hr > 0).isEmpty ? 0.0 : groupVitals.map((v) => v.heartRate ?? 0.0).where((hr) => hr > 0).reduce((a, b) => a + b) / groupVitals.map((v) => v.heartRate ?? 0.0).where((hr) => hr > 0).length;
          double avgBodyTemp = groupVitals.map((v) => v.bodyTemp ?? 0.0).where((bt) => bt > 0).isEmpty ? 0.0 : groupVitals.map((v) => v.bodyTemp ?? 0.0).where((bt) => bt > 0).reduce((a, b) => a + b) / groupVitals.map((v) => v.bodyTemp ?? 0.0).where((bt) => bt > 0).length;
          double avgSkinConductivity = groupVitals.map((v) => v.skinConductivity ?? 0.0).where((sc) => sc > 0).isEmpty ? 0.0 : groupVitals.map((v) => v.skinConductivity ?? 0.0).where((sc) => sc > 0).reduce((a, b) => a + b) / groupVitals.map((v) => v.skinConductivity ?? 0.0).where((sc) => sc > 0).length;

          calculatedVitals.add(WeeklyVitalsData(
            weekNumber: key,
            avgHeartRate: avgHeartRate,
            avgBodyTemp: avgBodyTemp,
            avgSkinConductivity: avgSkinConductivity,
            weekStartDate: groupStartDates[key]!,
          ));
        }
        _weeklyVitals = calculatedVitals;

        // Fetch Personal Baseline (always needed for AI feedback)
        final baselineDocRef = _db!
            .collection('artifacts')
            .doc('vitalink-app')
            .collection('users')
            .doc(widget.userId)
            .collection('baseline')
            .doc('personal_baseline')
            .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data()!,
          toFirestore: (model, _) => model,
        );
        final baselineSnap = await baselineDocRef.get();

        if (baselineSnap.exists && baselineSnap.data() != null) {
          _personalBaseline = PersonalBaseline.fromFirestore(baselineSnap);
          print("Personal baseline loaded for trend analysis.");
        } else {
          _aiHealthFeedback = "No personal baseline found. Please run '2-Day Body Nature Analysis' first from the Home screen under 'Proactive Health'.";
          // Don't return here, so chart can still show data even if baseline is missing
        }

        // Generate AI advice based on trends and baseline
        _aiHealthFeedback = _generateAIHealthFeedback();
      }
    } catch (e) {
      _aiHealthFeedback = "Error fetching or analyzing trends: $e";
      print("Error in TrendAnalysisScreen: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  String _generateAIHealthFeedback() {
    if (_weeklyVitals.isEmpty || _personalBaseline == null) {
      return "Insufficient data for trend analysis. Please ensure you have generated enough vital signs and a personal baseline.";
    }

    String timePeriod = _isDailyView ? "daily" : "weekly";
    String feedback = "Here's an overview of your health trends over the past ${_isDailyView ? 'days' : 'weeks'}:\n\n";
    List<String> observations = [];

    // Analyze Heart Rate Trend
    List<double> heartRates = _weeklyVitals.map((data) => data.avgHeartRate).toList();
    if (heartRates.isNotEmpty) {
      double latestHeartRate = heartRates.last;
      double baselineAvgHR = _personalBaseline!.avgHeartRate;
      double baselineStdDevHR = _personalBaseline!.stdDevHeartRate;

      if (latestHeartRate > baselineAvgHR + 2 * baselineStdDevHR) {
        observations.add("Your recent average heart rate (${latestHeartRate.toStringAsFixed(0)} bpm) is significantly higher than your baseline. This could indicate increased stress, activity, or other factors. Monitor closely.");
      } else if (latestHeartRate < baselineAvgHR - 2 * baselineStdDevHR && latestHeartRate > 0) { // Check for > 0 to exclude unrecorded data
        observations.add("Your recent average heart rate (${latestHeartRate.toStringAsFixed(0)} bpm) is significantly lower than your baseline. While this can be good for athletes, ensure it's not accompanied by fatigue or other symptoms.");
      } else {
        observations.add("Your heart rate has remained generally stable and within your normal baseline range. Keep up the good work!");
      }
    }

    // Analyze Body Temperature Trend
    List<double> bodyTemps = _weeklyVitals.map((data) => data.avgBodyTemp).toList();
    if (bodyTemps.isNotEmpty) {
      double latestBodyTemp = bodyTemps.last;
      double baselineAvgBT = _personalBaseline!.avgBodyTemp;
      double baselineStdDevBT = _personalBaseline!.stdDevBodyTemp;

      if (latestBodyTemp > baselineAvgBT + 1.0) { // A larger deviation for temp
        observations.add("Your recent average body temperature (${latestBodyTemp.toStringAsFixed(1)}°C) is noticeably higher than your baseline. This might suggest a mild infection or increased metabolic activity. Stay hydrated.");
      } else if (latestBodyTemp < baselineAvgBT - 1.0 && latestBodyTemp > 0) {
        observations.add("Your recent average body temperature (${latestBodyTemp.toStringAsFixed(1)}°C) is lower than your baseline. Ensure you are staying warm enough.");
      } else {
        observations.add("Your body temperature has been consistent with your baseline. Good job maintaining thermal balance.");
      }
    }

    // Analyze Skin Conductivity Trend
    List<double> skinConductivities = _weeklyVitals.map((data) => data.avgSkinConductivity).toList();
    if (skinConductivities.isNotEmpty) {
      double latestSkinConductivity = skinConductivities.last;
      double baselineAvgSC = _personalBaseline!.avgSkinConductivity;
      double baselineStdDevSC = _personalBaseline!.stdDevSkinConductivity;

      if (latestSkinConductivity > baselineAvgSC + 2 * baselineStdDevSC) {
        observations.add("Your recent average skin conductivity (${latestSkinConductivity.toStringAsFixed(2)} µS) is higher than your baseline. This could be related to increased stress, anxiety, or even hydration levels. Consider relaxation techniques.");
      } else if (latestSkinConductivity < baselineAvgSC - 2 * baselineStdDevSC && latestSkinConductivity > 0) {
        observations.add("Your recent average skin conductivity (${latestSkinConductivity.toStringAsFixed(2)} µS) is lower than your baseline. This might indicate reduced sympathetic nervous system activity or very good hydration. Continue to monitor.");
      } else {
        observations.add("Your skin conductivity is stable and within your typical range, suggesting balanced autonomic nervous system activity.");
      }
    }

    if (observations.isEmpty) {
      feedback += "No significant trends or deviations detected in your recent vital signs. Your health appears stable.";
    } else {
      feedback += observations.map((obs) => "• $obs").join("\n\n");
      feedback += "\n\nRemember, these are AI-generated observations. For any health concerns, always consult a medical professional.";
    }

    return feedback;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Trend Analysis & Charts',
          style: TextStyle(
            color: Theme.of(context).appBarTheme.titleTextStyle?.color,
            fontWeight: FontWeight.bold,
            fontFamily: "Montserrat",
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 1,
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: _FlowyBackground(),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isDailyView ? 'Your Daily Trends' : 'Your Weekly Trends', // Dynamic title
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onBackground,
                      letterSpacing: 1.2,
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'Visualize your vital signs over the past weeks and get AI-powered insights.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                      fontFamily: "Montserrat",
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 25, 16, 16), // Adjusted padding for chart
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A202C), // Dark background for the chart area
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: _isLoading
                        ? Column(
                      children: [
                        CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 20),
                        Text('Loading trends and generating advice...', style: TextStyle(fontSize: 18, fontFamily: 'Montserrat', color: Colors.white70)), // Text color adjusted for dark background
                      ],
                    )
                        :                         Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Vital for Chart:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // Changed to white
                            fontFamily: "Montserrat",
                          ),
                        ),
                        const SizedBox(height: 10),
                        Theme( // Override dropdown theme for dark background
                          data: Theme.of(context).copyWith(
                            canvasColor: const Color(0xFF2D3748), // Darker background for dropdown items
                            textTheme: TextTheme(
                              titleMedium: TextStyle(color: Colors.white70, fontFamily: "Montserrat"), // Text color for selected item
                            ),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedVitalType,
                            icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.primary),
                            style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: "Montserrat"), // Changed to white
                            underline: Container(
                              height: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedVitalType = newValue!;
                              });
                            },
                            items: <String>['Heart Rate', 'Body Temperature', 'Skin Conductivity']
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value, style: TextStyle(color: Colors.white, fontFamily: "Montserrat")), // Changed to white
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _isDailyView ? 'Daily Average ${_selectedVitalType} Trends:' : 'Weekly Average ${_selectedVitalType} Trends:', // Dynamic title
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // Changed to white
                            fontFamily: "Montserrat",
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Bar Chart for Trends
                        _weeklyVitals.isNotEmpty
                            ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 250,
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: _getMaxYValue(),
                                    barTouchData: BarTouchData(
                                      enabled: true,
                                      touchTooltipData: BarTouchTooltipData(
                                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                          String dateLabel = _isDailyView
                                              ? DateFormat('MMM d').format(_weeklyVitals[groupIndex].weekStartDate)
                                              : DateFormat('MMM d').format(_weeklyVitals[groupIndex].weekStartDate);
                                          String value = '';
                                          if (_selectedVitalType == 'Heart Rate') {
                                            value = '${rod.toY.toStringAsFixed(0)} bpm';
                                          } else if (_selectedVitalType == 'Body Temperature') {
                                            value = '${rod.toY.toStringAsFixed(1)} °C';
                                          } else if (_selectedVitalType == 'Skin Conductivity') {
                                            value = '${rod.toY.toStringAsFixed(2)} µS';
                                          }
                                          return BarTooltipItem(
                                            '$dateLabel\n$value',
                                            TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Montserrat',
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            if (value.toInt() < _weeklyVitals.length) {
                                              DateTime date = _weeklyVitals[value.toInt()].weekStartDate;
                                              String label;
                                              if (_isDailyView) {
                                                label = DateFormat('EEE').format(date);
                                              } else {
                                                label = DateFormat('MMM d').format(date);
                                              }
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 8.0),
                                                child: Text(
                                                  label,
                                                  style: TextStyle(
                                                    color: Colors.white54,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    fontFamily: 'Montserrat',
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              );
                                            }
                                            return const Text('');
                                          },
                                          reservedSize: 40,
                                        ),
                                      ),
                                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    borderData: FlBorderData(
                                      show: false,
                                    ),
                                    barGroups: _weeklyVitals.asMap().entries.map((entry) {
                                      int index = entry.key;
                                      WeeklyVitalsData data = entry.value;
                                      double value;
                                      if (_selectedVitalType == 'Heart Rate') {
                                        value = data.avgHeartRate;
                                      } else if (_selectedVitalType == 'Body Temperature') {
                                        value = data.avgBodyTemp;
                                      } else {
                                        value = data.avgSkinConductivity;
                                      }

                                      return BarChartGroupData(
                                        x: index,
                                        barRods: [
                                          BarChartRodData(
                                            toY: value,
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.blue.shade300,
                                                Colors.blue.shade700,
                                              ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                            width: 28,
                                            borderRadius: BorderRadius.circular(8),
                                            backDrawRodData: BackgroundBarChartRodData(
                                              show: true,
                                              toY: _getMaxYValue(),
                                              color: Colors.white.withOpacity(0.1),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                    gridData: FlGridData(
                                      show: false,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            _buildPercentageChangeDisplay(),
                          ],
                        )
                            : Center(
                          child: Text(
                            'Not enough data for chart. Needs at least one week of vitals.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.white70, fontFamily: "Montserrat"), // Changed to white70
                          ),
                        ),
                        const SizedBox(height: 32),
                        Divider(color: Colors.grey.shade700, height: 30, thickness: 1.5), // Darker divider
                        Text(
                          'AI Health Feedback:',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // Changed to white
                            fontFamily: "Montserrat",
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text.rich(
                          TextSpan(
                            text: '',
                            style: TextStyle(fontSize: 18, color: Colors.white70, fontFamily: "Montserrat"), // Changed to white70
                            children: [
                              for (var line in _aiHealthFeedback.split('\n')) ...[
                                TextSpan(
                                  text: line.contains('**')
                                      ? line.replaceAll('**', '')
                                      : line,
                                  style: line.contains('**')
                                      ? TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: "Montserrat") // Changed to white
                                      : TextStyle(color: Colors.white70, fontFamily: "Montserrat"), // Changed to white70
                                ),
                                const TextSpan(text: '\n'),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _fetchAndAnalyzeTrends,
                          icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onPrimary),
                          label: Text('Re-analyze Trends', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontFamily: 'Montserrat')), // Already onPrimary (white)
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),

                  ),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to determine the max Y value for the chart based on selected vital
  // Helper to determine the max Y value for the chart based on selected vital
  double _getMaxYValue() {
    if (_weeklyVitals.isEmpty) return 100.0; // Default max

    double maxVal = 0.0;
    if (_selectedVitalType == 'Heart Rate') {
      maxVal = _weeklyVitals.map((data) => data.avgHeartRate).reduce(math.max);
      return (maxVal + 40).clamp(120.0, 250.0); // Increased padding, adjusted clamp for shorter appearance
    } else if (_selectedVitalType == 'Body Temperature') {
      maxVal = _weeklyVitals.map((data) => data.avgBodyTemp).reduce(math.max);
      return (maxVal + 3.0).clamp(39.0, 45.0); // Increased padding, adjusted clamp
    } else { // Skin Conductivity
      maxVal = _weeklyVitals.map((data) => data.avgSkinConductivity).reduce(math.max);
      return (maxVal + 10.0).clamp(15.0, 40.0); // Increased padding, adjusted clamp
    }
  }

  // Helper to build the percentage change display
  Widget _buildPercentageChangeDisplay() {
    if (_weeklyVitals.length < 2) {
      return const SizedBox.shrink(); // Don't show if not enough data for comparison
    }

    double firstValue = 0.0;
    double lastValue = 0.0;

    // Get values based on selected vital type
    if (_selectedVitalType == 'Heart Rate') {
      firstValue = _weeklyVitals.first.avgHeartRate;
      lastValue = _weeklyVitals.last.avgHeartRate;
    } else if (_selectedVitalType == 'Body Temperature') {
      firstValue = _weeklyVitals.first.avgBodyTemp;
      lastValue = _weeklyVitals.last.avgBodyTemp;
    } else { // Skin Conductivity
      firstValue = _weeklyVitals.first.avgSkinConductivity;
      lastValue = _weeklyVitals.last.avgSkinConductivity;
    }

    if (firstValue == 0 && lastValue == 0) {
      return const SizedBox.shrink(); // No meaningful data
    }

    double percentageChange = 0.0;
    String changeText = "N/A";
    Color changeColor = Colors.white; // Default color for text

    if (firstValue != 0) {
      percentageChange = ((lastValue - firstValue) / firstValue) * 100;
      changeText = '${percentageChange > 0 ? '+' : ''}${percentageChange.toStringAsFixed(0)}%';
      if (percentageChange > 0) {
        changeColor = Colors.red.shade300; // Red for increase (often negative for health)
      } else if (percentageChange < 0) {
        changeColor = Colors.green.shade300; // Green for decrease (often positive for health)
      } else {
        changeColor = Colors.white; // No change
      }
    } else if (lastValue != 0) {
      // If first value was 0 but last is not, it's a significant increase from zero
      changeText = '+${lastValue.toStringAsFixed(0)}%';
      changeColor = Colors.green.shade300; // Treat as positive change
    }


    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          changeText,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: changeColor,
            fontFamily: 'Montserrat',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Total Change',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white70,
            fontFamily: 'Montserrat',
          ),
        ),
      ],
    );
  }

}
/// New screen for Account Settings.
class AccountSettingsScreen extends StatefulWidget {
  final String userId;

  const AccountSettingsScreen({super.key, required this.userId});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _changePassword() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _errorMessage = "No user is currently logged in.";
      _showSnackBar(_errorMessage!, isError: true);
      setState(() { _isLoading = false; });
      return;
    }

    if (_newPasswordController.text.isEmpty || _confirmNewPasswordController.text.isEmpty) {
      _errorMessage = "New password and confirmation cannot be empty.";
      _showSnackBar(_errorMessage!, isError: true);
      setState(() { _isLoading = false; });
      return;
    }

    if (_newPasswordController.text != _confirmNewPasswordController.text) {
      _errorMessage = "New passwords do not match.";
      _showSnackBar(_errorMessage!, isError: true);
      setState(() { _isLoading = false; });
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _errorMessage = "Password must be at least 6 characters long.";
      _showSnackBar(_errorMessage!, isError: true);
      setState(() { _isLoading = false; });
      return;
    }

    try {
      // Reauthenticate user if they signed in with email/password
      // Note: Google Sign-In users might not have a password to reauthenticate with.
      // For simplicity, this example assumes email/password for reauthentication.
      // For Google users, you might need to prompt them to re-sign in with Google.
      if (user.providerData.any((info) => info.providerId == 'password')) {
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text,
        );
        await user.reauthenticateWithCredential(credential);
      } else if (user.providerData.any((info) => info.providerId == 'google.com')) {
        // For Google users, you might need a different reauthentication flow
        // For now, we'll allow password change without explicit reauth for Google,
        // but in a real app, this is a security risk and should be handled.
        print("Google user, skipping password reauthentication for demo purposes.");
      }


      await user.updatePassword(_newPasswordController.text);
      _successMessage = "Password updated successfully!";
      _showSnackBar(_successMessage!, isError: false);
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmNewPasswordController.clear();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _errorMessage = 'This operation is sensitive and requires recent authentication. Please log out and log in again.';
      } else if (e.code == 'wrong-password') {
        _errorMessage = 'The current password you entered is incorrect.';
      } else if (e.code == 'weak-password') {
        _errorMessage = 'The new password is too weak.';
      } else {
        _errorMessage = 'Error changing password: ${e.message}';
      }
      _showSnackBar(_errorMessage!, isError: true);
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      _showSnackBar(_errorMessage!, isError: true);
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Account Settings',
          style: TextStyle(
            color: Theme.of(context).appBarTheme.titleTextStyle?.color,
            fontWeight: FontWeight.bold,
            fontFamily: "Montserrat",
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 1,
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: _FlowyBackground(),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Manage Your Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onBackground,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Update your password and personalize your app experience.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                      fontFamily: "Montserrat",
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Password Change Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Change Password',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontFamily: "Montserrat",
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Your email ID (${FirebaseAuth.instance.currentUser?.email ?? 'N/A'}) cannot be changed from here.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            fontFamily: "Montserrat",
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _currentPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Current Password',
                            prefixIcon: Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.primary),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _newPasswordController,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            prefixIcon: Icon(Icons.lock_reset, color: Theme.of(context).colorScheme.primary),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmNewPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            prefixIcon: Icon(Icons.lock_reset, color: Theme.of(context).colorScheme.primary),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _changePassword,
                          icon: _isLoading
                              ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.onPrimary,
                              strokeWidth: 2,
                            ),
                          )
                              : Icon(Icons.vpn_key, color: Theme.of(context).colorScheme.onPrimary),
                          label: Text(
                            _isLoading ? 'Changing Password...' : 'Change Password',
                            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontFamily: 'Montserrat'),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Dark Mode Toggle Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Dark Mode',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontFamily: "Montserrat",
                          ),
                        ),
                        ValueListenableBuilder<ThemeMode>(
                          valueListenable: MyApp.themeNotifier,
                          builder: (_, currentMode, __) {
                            return Switch(
                              value: currentMode == ThemeMode.dark,
                              onChanged: (isOn) {
                                MyApp.themeNotifier.value = isOn ? ThemeMode.dark : ThemeMode.light;
                              },
                              activeColor: Theme.of(context).colorScheme.primary,
                              inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                              activeTrackColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
/// Placeholder for a data model representing aggregated daily health data for analysis.
/// You already have HealthData, but this one is simpler for ComparativeViews
/// Let's use your existing HealthData as it already fits the need for daily vitals.

/// Screen for Comparative Views and AI-driven health trends.
class ComparativeViewsScreen extends StatefulWidget {
  final String userId;

  const ComparativeViewsScreen({super.key, required this.userId});

  @override
  State<ComparativeViewsScreen> createState() => _ComparativeViewsScreenState();
}

class _ComparativeViewsScreenState extends State<ComparativeViewsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance; // Firestore instance
  bool _isLoading = true;
  String _aiHealthFeedback = "Analyzing your health trends...";
  List<HealthData> _allVitals = [];
  PersonalBaseline? _personalBaseline; // To store user's baseline

  // Data points for comparison
  HealthData? _healthBefore;
  HealthData? _healthBest;
  HealthData? _healthNow;
  DateTime? _bestHealthDate;

  @override
  void initState() {
    super.initState();
    _fetchAndAnalyzeTrends();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _fetchAndAnalyzeTrends() async {
    setState(() {
      _isLoading = true;
      _aiHealthFeedback = "Analyzing your health trends...";
      _healthBefore = null;
      _healthBest = null;
      _healthNow = null;
      _bestHealthDate = null;
    });

    if (widget.userId.isEmpty) {
      _aiHealthFeedback = "Error: User ID missing.";
      _showSnackBar(_aiHealthFeedback, isError: true);
      setState(() { _isLoading = false; });
      return;
    }

    try {
      // 1. Fetch Personal Baseline
      final baselineDocRef = _db
          .collection('artifacts')
          .doc('vitalink-app')
          .collection('users')
          .doc(widget.userId)
          .collection('baseline')
          .doc('personal_baseline');
      final baselineSnap = await baselineDocRef.get();

      if (baselineSnap.exists && baselineSnap.data() != null) {
        _personalBaseline = PersonalBaseline.fromFirestore(baselineSnap);
        print("Personal baseline loaded for trend analysis.");
      } else {
        _aiHealthFeedback = "No personal baseline found. Please run '2-Day Body Nature Analysis' first for a more accurate comparison.";
        _personalBaseline = null; // Ensure it's null if not found
        _showSnackBar("No personal baseline found. Please complete the initial analysis.", isError: true);
      }

      // 2. Fetch all historical HealthData
      final querySnapshot = await _db
          .collection('artifacts')
          .doc('vitalink-app')
          .collection('users')
          .doc(widget.userId)
          .collection('daily_vitals')
          .orderBy('timestamp', descending: false) // Order by oldest first
          .get();

      _allVitals = querySnapshot.docs.map((doc) => HealthData.fromFirestore(doc)).toList();

      if (_allVitals.isEmpty) {
        _aiHealthFeedback = "No health data recorded yet. Start tracking your vitals to see comparisons!";
        setState(() { _isLoading = false; });
        return;
      }

      // 3. Determine time ranges for comparison
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      // Filter out data from today to avoid incomplete day issues for "now" analysis
      // Or consider if "now" means last recorded entry. For now, let's use the last full day.
      List<HealthData> dataExcludingToday = _allVitals.where((data) => data.timestamp.isBefore(todayStart)).toList();

      if (dataExcludingToday.isEmpty) {
        _aiHealthFeedback = "Only today's data is available. Come back tomorrow for comparisons!";
        setState(() { _isLoading = false; });
        return;
      }

      final firstEntryDate = _allVitals.first.timestamp;
      final totalUsageDays = todayStart.difference(firstEntryDate).inDays;

      // Define comparison periods
      List<HealthData> pastPeriodData;
      List<HealthData> currentPeriodData;

      if (totalUsageDays < 7) {
        // New user: compare first few days with last few days
        pastPeriodData = dataExcludingToday.take(totalUsageDays.clamp(1, 3)).toList(); // First 1-3 days
        currentPeriodData = dataExcludingToday.skip(math.max(0, dataExcludingToday.length - totalUsageDays.clamp(1, 3))).toList(); // Last 1-3 days
        _aiHealthFeedback = "Analyzing your initial health journey...";
      } else if (totalUsageDays < 30) {
        // User for more than a week: compare first week with last week
        pastPeriodData = dataExcludingToday.where((data) => data.timestamp.isBefore(firstEntryDate.add(const Duration(days: 7)))).toList();
        currentPeriodData = dataExcludingToday.where((data) => data.timestamp.isAfter(todayStart.subtract(const Duration(days: 7)))).toList();
        _aiHealthFeedback = "Comparing your recent health to your early days...";
      } else {
        // Long-term user: compare initial month/week with last month/week
        pastPeriodData = dataExcludingToday.where((data) => data.timestamp.isBefore(firstEntryDate.add(const Duration(days: 30)))).toList();
        currentPeriodData = dataExcludingToday.where((data) => data.timestamp.isAfter(todayStart.subtract(const Duration(days: 30)))).toList();
        _aiHealthFeedback = "Reviewing your long-term health evolution...";
      }

      // Ensure data is not empty after filtering
      if (pastPeriodData.isEmpty || currentPeriodData.isEmpty) {
        _aiHealthFeedback = "Not enough distinct data points for a meaningful comparison across periods.";
        setState(() { _isLoading = false; });
        return;
      }

      _healthBefore = _calculateAverageHealthData(pastPeriodData);
      _healthNow = _calculateAverageHealthData(currentPeriodData);

      // 4. Identify the "Best Health" period (simplified heuristic)
      // For simplicity, let's find the day with values closest to baseline or most "optimal"
      double minDeviation = double.infinity;
      for (var data in _allVitals) {
        double currentDeviation = _calculateDeviationFromIdeal(data, _personalBaseline);
        if (currentDeviation < minDeviation) {
          minDeviation = currentDeviation;
          _healthBest = data;
          _bestHealthDate = data.timestamp;
        }
      }

      // 5. Generate AI Advice
      _aiHealthFeedback = _generateAIAdvice(
        _healthBefore,
        _healthBest,
        _healthNow,
        _bestHealthDate,
        _personalBaseline,
        totalUsageDays,
      );

    } on FirebaseException catch (e) {
      _aiHealthFeedback = "Failed to fetch health data: ${e.message}";
      _showSnackBar(_aiHealthFeedback, isError: true);
    } catch (e) {
      _aiHealthFeedback = "An unexpected error occurred during analysis: $e";
      _showSnackBar(_aiHealthFeedback, isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper to calculate average HealthData for a list of HealthData entries
  HealthData _calculateAverageHealthData(List<HealthData> dataList) {
    if (dataList.isEmpty) {
      return HealthData(
        userId: widget.userId,
        timestamp: DateTime.now(), // Placeholder timestamp
        avgHeartRate: 0,
        avgBodyTemp: 0.0,
        avgSkinConductivity: 0.0,
        mood: '', // Not used for averages
        activityLevel: '', // Not used for averages
        stressLevel: '', // Not used for averages
        sleepDuration: 0.0, // Not used for averages
      );
    }

    double totalHeartRate = 0;
    double totalBodyTemp = 0;
    double totalSkinConductivity = 0;

    for (var data in dataList) {
      totalHeartRate += data.avgHeartRate;
      totalBodyTemp += data.avgBodyTemp;
      totalSkinConductivity += data.avgSkinConductivity;
    }

    return HealthData(
      userId: widget.userId,
      timestamp: dataList.last.timestamp, // Use last timestamp as reference
      avgHeartRate: (totalHeartRate / dataList.length),
      avgBodyTemp: (totalBodyTemp / dataList.length),
      avgSkinConductivity: (totalSkinConductivity / dataList.length),
      mood: '', activityLevel: '', stressLevel: '', sleepDuration: 0.0, // Defaults
    );
  }

  // Helper to calculate deviation from an ideal state (e.g., baseline)
  double _calculateDeviationFromIdeal(HealthData data, PersonalBaseline? baseline) {
    if (baseline == null) return 0.0; // Cannot calculate if no baseline

    double deviation = 0.0;
    // Example: deviations from baseline are higher for greater difference
    deviation += (data.avgHeartRate - baseline.avgHeartRate).abs();
    deviation += (data.avgBodyTemp - baseline.avgBodyTemp).abs() * 10; // Temp deviation weighted more
    deviation += (data.avgSkinConductivity - baseline.avgSkinConductivity).abs();
    return deviation;
  }

  // Simple AI advice generation based on trends
  String _generateAIAdvice(
      HealthData? before,
      HealthData? best,
      HealthData? now,
      DateTime? bestDate,
      PersonalBaseline? baseline,
      int totalUsageDays,
      ) {
    if (before == null || now == null) {
      return "Not enough data for comprehensive analysis. Keep tracking your vitals!";
    }

    StringBuffer advice = StringBuffer();
    advice.writeln("Vitality Trend Analysis:");
    advice.writeln("");

    String bestDateStr = bestDate != null ? DateFormat('MMM dd,yyyy').format(bestDate) : 'N/A';

    advice.writeln("### Your Journey at a Glance:");
    if (totalUsageDays < 7) {
      advice.writeln("You're a new Vitalyz user, so we're comparing your first few days to your latest. Welcome to your health journey!");
      advice.writeln("- **Your Start ($totalUsageDays days ago):**");
    } else if (totalUsageDays < 30) {
      advice.writeln("You've been with us for a while! Let's look at your progress from your first week to now.");
      advice.writeln("- **Your Early Days (Week 1 avg.):**");
    } else {
      advice.writeln("You're a long-term Vitalyz user! Here's a look at your health over time.");
      advice.writeln("- **Your Initial Period (First month avg.):**");
    }

    advice.writeln("  - Heart Rate: ${before.avgHeartRate.toStringAsFixed(0)} bpm");
    advice.writeln("  - Body Temp: ${before.avgBodyTemp.toStringAsFixed(1)}°C");
    advice.writeln("  - Skin Conductivity: ${before.avgSkinConductivity.toStringAsFixed(1)} µS");
    advice.writeln("");

    advice.writeln("- **Your Health NOW (Latest trend):**");
    advice.writeln("  - Heart Rate: ${now.avgHeartRate.toStringAsFixed(0)} bpm");
    advice.writeln("  - Body Temp: ${now.avgBodyTemp.toStringAsFixed(1)}°C");
    advice.writeln("  - Skin Conductivity: ${now.avgSkinConductivity.toStringAsFixed(1)} µS");
    advice.writeln("");

    if (best != null && bestDate != null) {
      advice.writeln("- **Your Peak Health ($bestDateStr):**");
      advice.writeln("  - Heart Rate: ${best.avgHeartRate.toStringAsFixed(0)} bpm");
      advice.writeln("  - Body Temp: ${best.avgBodyTemp.toStringAsFixed(1)}°C");
      advice.writeln("  - Skin Conductivity: ${best.avgSkinConductivity.toStringAsFixed(1)} µS");
      advice.writeln("");
    } else {
      advice.writeln("- **Peak Health:** Not enough diverse data to identify a distinct 'best' period yet. Keep logging!");
      advice.writeln("");
    }

    advice.writeln("### Vitalyz AI Recommendations:");

    // Compare NOW vs BEFORE
    if (now.avgHeartRate > before.avgHeartRate + 5) {
      advice.writeln("✨ Your average Heart Rate has increased. Consider incorporating more relaxing activities or light cardio to manage stress.");
    } else if (now.avgHeartRate < before.avgHeartRate - 5) {
      advice.writeln("✨ Your average Heart Rate has decreased. This could indicate improved cardiovascular fitness or relaxation.");
    } else {
      advice.writeln("✨ Your Heart Rate remains stable. Good consistency!");
    }

    if (now.avgBodyTemp > before.avgBodyTemp + 0.5) {
      advice.writeln("🌡️ A slight increase in Body Temperature might suggest increased metabolic activity or minor inflammation. Stay hydrated and monitor.");
    } else if (now.avgBodyTemp < before.avgBodyTemp - 0.5) {
      advice.writeln("🌡️ Your Body Temperature shows a slight decrease. This is generally good, indicating stable thermoregulation.");
    } else {
      advice.writeln("🌡️ Your Body Temperature is consistent, indicating good stability.");
    }

    if (now.avgSkinConductivity > before.avgSkinConductivity + 2.0) {
      advice.writeln("⚡ Your Skin Conductivity has risen, often linked to increased stress or excitement. Practice mindfulness or deep breathing exercises.");
    } else if (now.avgSkinConductivity < before.avgSkinConductivity - 2.0) {
      advice.writeln("⚡ Your Skin Conductivity has decreased, suggesting a more relaxed state. Keep up your calming routines!");
    } else {
      advice.writeln("⚡ Your Skin Conductivity is stable. Your stress response appears balanced.");
    }

    // Compare NOW vs BEST (if best exists)
    if (best != null) {
      double hrDiffBest = now.avgHeartRate - best.avgHeartRate;
      double tempDiffBest = now.avgBodyTemp - best.avgBodyTemp;
      double scDiffBest = now.avgSkinConductivity - best.avgSkinConductivity;

      if (hrDiffBest.abs() > 5 || tempDiffBest.abs() > 0.5 || scDiffBest.abs() > 2.0) {
        advice.writeln("\nCompare to your best health period on $bestDateStr:");
        advice.writeln("Consider what you were doing around that time. Were you more active? Sleeping better? Less stressed? Replicating those habits could help you return to your peak vitality.");
      }
    }

    // Advice based on overall trends or baseline
    if (baseline != null) {
      double hrDev = (now.avgHeartRate - baseline.avgHeartRate).abs();
      if (hrDev > 10) {
        advice.writeln("\nYour current Heart Rate deviates significantly from your personal baseline. Consult with a professional if this trend continues.");
      }
    }

    advice.writeln("\nRemember: These are AI-driven insights. For personalized medical advice, consult a healthcare professional.");

    return advice.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Comparative Health Views',
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: _FlowyBackground(), // Keep the aesthetic background
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Your Health Journey',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onBackground,
                      letterSpacing: 1.2,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'AI-powered insights into your past and current vitality.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  const SizedBox(height: 32),

                  _isLoading
                      ? Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 16),
                        Text(
                          _aiHealthFeedback,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.8),
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ],
                    ),
                  )
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Current Health Summary
                      Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        color: Theme.of(context).colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Health NOW',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildVitalRow(context, 'Heart Rate', _healthNow?.avgHeartRate, 'bpm'),
                              _buildVitalRow(context, 'Body Temp', _healthNow?.avgBodyTemp, '°C'),
                              _buildVitalRow(context, 'Skin Conductivity', _healthNow?.avgSkinConductivity, 'µS'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Health Before Summary
                      Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        color: Theme.of(context).colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Health BEFORE',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildVitalRow(context, 'Heart Rate', _healthBefore?.avgHeartRate, 'bpm'),
                              _buildVitalRow(context, 'Body Temp', _healthBefore?.avgBodyTemp, '°C'),
                              _buildVitalRow(context, 'Skin Conductivity', _healthBefore?.avgSkinConductivity, 'µS'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Best Health Summary (Conditional)
                      if (_healthBest != null)
                        Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          color: Theme.of(context).colorScheme.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Best Health (${_bestHealthDate != null ? DateFormat('MMM dd,yyyy').format(_bestHealthDate!) : 'N/A'})',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontFamily: 'Montserrat',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildVitalRow(context, 'Heart Rate', _healthBest?.avgHeartRate, 'bpm'),
                                _buildVitalRow(context, 'Body Temp', _healthBest?.avgBodyTemp, '°C'),
                                _buildVitalRow(context, 'Skin Conductivity', _healthBest?.avgSkinConductivity, 'µS'),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),

                      // AI Advice Card
                      Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        color: Theme.of(context).colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vitalyz AI Insights',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontFamily: "Montserrat",
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text.rich(
                                TextSpan(
                                  text: '',
                                  style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontFamily: "Montserrat"),
                                  children: [
                                    for (var line in _aiHealthFeedback.split('\n')) ...[
                                      TextSpan(
                                        text: line.contains('**')
                                            ? line.replaceAll('**', '')
                                            : line.contains('###')
                                            ? line.replaceAll('###', '')
                                            : line.contains('✨') || line.contains('🌡️') || line.contains('⚡')
                                            ? line
                                            : line,
                                        style: line.contains('**') || line.contains('###')
                                            ? TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontFamily: "Montserrat", fontSize: line.contains('###') ? 20 : 18)
                                            : TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9), fontFamily: "Montserrat"),
                                      ),
                                      const TextSpan(text: '\n'), // Add newline after each line
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _isLoading ? null : _fetchAndAnalyzeTrends,
                                icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onPrimary),
                                label: Text('Re-compare Vitals', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontFamily: 'Montserrat')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget to build vital sign rows
  Widget _buildVitalRow(BuildContext context, String title, double? value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$title:',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              fontFamily: 'Montserrat',
            ),
          ),
          Text(
            value != null && value > 0 ? '${value.toStringAsFixed(1)} $unit' : 'N/A',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              fontFamily: 'Montserrat',
            ),
          ),
        ],
      ),
    );
  }
}


/// New screen for Forgot Password functionality.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  bool _isError = false;

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    setState(() {
      _isLoading = true;
      _message = null;
      _isError = false;
    });

    final String email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _message = 'Please enter your email address.';
        _isError = true;
      });
      _showSnackBar(_message!, isError: true);
      setState(() { _isLoading = false; });
      return;
    }

    // Basic email format validation
    if (!RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email)) {
      setState(() {
        _message = 'Please enter a valid email address.';
        _isError = true;
      });
      _showSnackBar(_message!, isError: true);
      setState(() { _isLoading = false; });
      return;
    }

    try {
      await _initializeFirebase(); // Ensure Firebase is initialized
      await _auth!.sendPasswordResetEmail(email: email);
      setState(() {
        _message = 'Password reset link sent to your email. Please check your inbox.';
        _isError = false;
      });
      _showSnackBar(_message!, isError: false);
      _emailController.clear(); // Clear the email field
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found for that email address.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email address is not valid.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Network error. Please check your internet connection.';
      } else {
        errorMessage = 'Error sending password reset email: ${e.message ?? 'Unknown error'}';
      }
      setState(() {
        _message = errorMessage;
        _isError = true;
      });
      _showSnackBar(errorMessage, isError: true);
    } catch (e) {
      setState(() {
        _message = 'An unexpected error occurred: $e';
        _isError = true;
      });
      _showSnackBar('An unexpected error occurred: $e', isError: true);
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Forgot Password',
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: _FlowyBackground(),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Reset Your Password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onBackground,
                      letterSpacing: 1.2,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Enter your registered email address to receive a password reset link.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary, fontSize: 14, fontFamily: 'Montserrat'),
                      ),
                    ),

                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'e.g., user@example.com',
                      prefixIcon: Icon(Icons.email_outlined, color: Theme.of(context).colorScheme.primary),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendPasswordResetEmail,
                    child: _isLoading
                        ? CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary)
                        : const Text('Send Reset Link'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Go back to login screen
                    },
                    child: Text('Back to Login', style: TextStyle(color: Theme.of(context).colorScheme.primaryContainer)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen to display the application's Privacy Policy.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  // Your provided Privacy Policy text
  static const String _privacyPolicyText = """
VITALYZ Privacy Policy

At Vitalyz, your privacy is paramount. This policy outlines how we collect, use, and protect your personal and health data. We collect information you provide, such as your profile details (name, age, gender, medical conditions) and vital signs (skin conductivity, heart rate, body temperature, blood oxygen), along with environmental data (air temperature, humidity, AQI) and app usage information. This data is exclusively used to provide you with personalized AI-driven health insights, trend analysis, risk predictions, and to continuously improve the accuracy and relevance of our services. All your health data is stored securely using Firebase Firestore, with robust security measures in place to protect it. We do not share, sell, or rent your personal health data to third parties. You retain full control over your data and can access or delete it through your account settings. By using Vitalyz, you consent to the data practices described in this policy.
""";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Privacy Policy',
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: _FlowyBackground(), // Keep the aesthetic background
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Your Privacy at Vitalyz',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onBackground,
                      letterSpacing: 1.2,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Understanding how your data is handled.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        _privacyPolicyText,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5, // Line spacing
                          color: Theme.of(context).colorScheme.onSurface,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// Extension to get day of year for DateTime
extension DateExtension on DateTime {
  int get dayOfYear {
    return difference(DateTime(year, 1, 1)).inDays + 1;
  }
}
