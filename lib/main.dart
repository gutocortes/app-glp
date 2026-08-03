import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TirzeTrackApp());
}

class TirzeTrackApp extends StatelessWidget {
  const TirzeTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TirzeTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0061A4), brightness: Brightness.light),
      ),
      home: const MainAppController(),
    );
  }
}

// -----------------------------------------------------------------------------
// MODELOS E PERSISTÊNCIA
// -----------------------------------------------------------------------------
class UserProfile {
  String name, email, photoUrl, gender, goal;
  int age, injectionIntervalDays;
  double weight, height;
  bool isInitialSetupDone, isLoggedIn;

  UserProfile({
    this.name = '', this.email = '', this.photoUrl = '', this.age = 0,
    this.weight = 0.0, this.height = 0.0, this.gender = 'Masculino',
    this.goal = 'Emagrecimento GLP-1', this.injectionIntervalDays = 7, 
    this.isInitialSetupDone = false, this.isLoggedIn = false,
  });

  double get dailyCalories {
    double tbm = (gender == 'Masculino') ? (10 * weight + 6.25 * height - 5 * age + 5) : (10 * weight + 6.25 * height - 5 * age - 161);
    double factor = 1.55; // Padrão moderado
    double base = tbm * factor;
    return (goal == 'Emagrecimento GLP-1') ? base * 0.72 : (goal == 'Perda Gradual' ? base * 0.85 : base);
  }
}

class InjectionLog {
  final String medication, dose, site;
  final DateTime dateTime;
  InjectionLog({required this.medication, required this.dose, required this.site, required this.dateTime});

  Map<String, dynamic> toJson() => {'med': medication, 'dose': dose, 'site': site, 'date': dateTime.toIso8601String()};
  factory InjectionLog.fromJson(Map<String, dynamic> json) => InjectionLog(
      medication: json['med'], dose: json['dose'], site: json['site'], dateTime: DateTime.parse(json['date']));
}

// -----------------------------------------------------------------------------
// CONTROLADOR COM PERSISTÊNCIA
// -----------------------------------------------------------------------------
class MainAppController extends StatefulWidget {
  const MainAppController({super.key});
  @override
  State<MainAppController> createState() => _MainAppControllerState();
}

class _MainAppControllerState extends State<MainAppController> {
  UserProfile profile = UserProfile();
  List<InjectionLog> injectionLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      profile.isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      profile.name = prefs.getString('userName') ?? '';
      profile.email = prefs.getString('userEmail') ?? '';
      profile.photoUrl = prefs.getString('userPhoto') ?? '';
      profile.isInitialSetupDone = prefs.getBool('isSetup') ?? false;
      
      final logsString = prefs.getString('logs');
      if (logsString != null) {
        injectionLogs = (jsonDecode(logsString) as List).map((e) => InjectionLog.fromJson(e)).toList();
      }
      _isLoading = false;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', profile.isLoggedIn);
    await prefs.setString('userName', profile.name);
    await prefs.setString('userEmail', profile.email);
    await prefs.setString('userPhoto', profile.photoUrl);
    await prefs.setBool('isSetup', profile.isInitialSetupDone);
    await prefs.setString('logs', jsonEncode(injectionLogs.map((e) => e.toJson()).toList()));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!profile.isLoggedIn) return LoginScreen(onLogin: (acc) {
      setState(() {
        profile.isLoggedIn = true;
        profile.name = acc?.displayName ?? "Usuário";
        profile.email = acc?.email ?? "";
        profile.photoUrl = acc?.photoUrl ?? "";
      });
      _saveData();
    });
    if (!profile.isInitialSetupDone) return OnboardingScreen(profile: profile, onComplete: () {
      setState(() => profile.isInitialSetupDone = true);
      _saveData();
    });
    return MainNavigationScreen(profile: profile, logs: injectionLogs, onAddInjection: (log) {
      setState(() => injectionLogs.add(log));
      _saveData();
    }, onLogout: () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      setState(() => profile = UserProfile());
    });
  }
}

// -----------------------------------------------------------------------------
// TELAS DO APP
// -----------------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  final Function(GoogleSignInAccount?) onLogin;
  const LoginScreen({super.key, required this.onLogin});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Future<void> _handleLogin() async {
    final user = await GoogleSignIn(scopes: ['email']).signIn();
    widget.onLogin(user);
  }
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: FilledButton(onPressed: _handleLogin, child: const Text("Entrar com Google"))));
}

class OnboardingScreen extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.profile, required this.onComplete});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: ElevatedButton(onPressed: widget.onComplete, child: const Text("Continuar"))));
}

class MainNavigationScreen extends StatelessWidget {
  final UserProfile profile;
  final List<InjectionLog> logs;
  final Function(InjectionLog) onAddInjection;
  final VoidCallback onLogout;
  const MainNavigationScreen({super.key, required this.profile, required this.logs, required this.onAddInjection, required this.onLogout});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text("Olá ${profile.name}"), actions: [IconButton(onPressed: onLogout, icon: const Icon(Icons.logout))]),
    body: Center(child: Text("Bem-vindo, ${profile.name}. Injeções salvas: ${logs.length}")),
  );
}
