import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        debugPrint("Timeout ao inicializar o Firebase. Continuando localmente.");
        return Firebase.app();
      },
    );
  } catch (e) {
    debugPrint("Erro ao inicializar Firebase: $e");
  }
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0061A4),
          brightness: Brightness.light,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
      home: const MainAppController(),
    );
  }
}

// -----------------------------------------------------------------------------
// MODELOS DE DADOS
// -----------------------------------------------------------------------------
class UserProfile {
  String name;
  String email;
  String photoUrl;
  int age;
  double weight;
  double height;
  String gender;
  String activityLevel;
  String goal;
  int injectionIntervalDays;
  bool isInitialSetupDone;
  bool isLoggedIn;

  UserProfile({
    this.name = '',
    this.email = '',
    this.photoUrl = '',
    this.age = 0,
    this.weight = 0.0,
    this.height = 0.0,
    this.gender = 'Masculino',
    this.activityLevel = 'Sedentário',
    this.goal = 'Emagrecimento GLP-1',
    this.injectionIntervalDays = 7,
    this.isInitialSetupDone = false,
    this.isLoggedIn = false,
  });

  double get imc {
    if (height <= 0) return 0.0;
    return weight / ((height / 100) * (height / 100));
  }

  String get imcClassification {
    double val = imc;
    if (val <= 0) return 'Não calculado';
    if (val < 18.5) return 'Abaixo do peso';
    if (val < 25.0) return 'Peso normal';
    if (val < 30.0) return 'Sobrepeso';
    if (val < 35.0) return 'Obesidade Grau I';
    if (val < 40.0) return 'Obesidade Grau II';
    return 'Obesidade Grau III';
  }

  double get tbm {
    if (weight <= 0 || height <= 0 || age <= 0) return 0.0;
    if (gender == 'Masculino') {
      return (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      return (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }
  }

  double get maintenanceCalories {
    double factor = 1.2;
    if (activityLevel == 'Leve') factor = 1.375;
    if (activityLevel == 'Moderado') factor = 1.55;
    if (activityLevel == 'Intenso') factor = 1.725;
    return tbm * factor;
  }

  double get dailyCalories {
    double base = maintenanceCalories;
    if (goal == 'Emagrecimento GLP-1') {
      return base * 0.72;
    } else if (goal == 'Perda Gradual') {
      return base * 0.85;
    }
    return base;
  }
}

class InjectionLog {
  final String medication;
  final String dose;
  final String site;
  final DateTime dateTime;

  InjectionLog({
    required this.medication,
    required this.dose,
    required this.site,
    required this.dateTime,
  });

  Map<String, dynamic> toJson() => {
        'medication': medication,
        'dose': dose,
        'site': site,
        'dateTime': dateTime.toIso8601String(),
      };

  factory InjectionLog.fromJson(Map<String, dynamic> json) => InjectionLog(
        medication: json['medication'] ?? '',
        dose: json['dose'] ?? '',
        site: json['site'] ?? '',
        dateTime: DateTime.parse(json['dateTime']),
      );
}

class WeightLog {
  final double weight;
  final DateTime date;

  WeightLog(this.weight, this.date);

  Map<String, dynamic> toJson() => {
        'weight': weight,
        'date': date.toIso8601String(),
      };

  factory WeightLog.fromJson(Map<String, dynamic> json) => WeightLog(
        (json['weight'] as num).toDouble(),
        DateTime.parse(json['date']),
      );
}

// -----------------------------------------------------------------------------
// CONTROLADOR PRINCIPAL
// -----------------------------------------------------------------------------
class MainAppController extends StatefulWidget {
  const MainAppController({super.key});

  @override
  State<MainAppController> createState() => _MainAppControllerState();
}

class _MainAppControllerState extends State<MainAppController> {
  final UserProfile profile = UserProfile();
  bool _isLoading = true;
  int waterIntakeMl = 0;
  final int waterGoalMl = 2500;
  int consumedCalories = 0;

  List<InjectionLog> injectionLogs = [];
  List<WeightLog> weightLogs = [];

  @override
  void initState() {
    super.initState();
    _loadStoredUserData();
  }

  Future<void> _loadStoredUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      User? currentUser;
      try {
        currentUser = FirebaseAuth.instance.currentUser;
      } catch (e) {
        debugPrint("Erro ao checar FirebaseAuth: $e");
      }

      setState(() {
        profile.isLoggedIn = (prefs.getBool('isLoggedIn') ?? false) || (currentUser != null);
        profile.isInitialSetupDone = prefs.getBool('isInitialSetupDone') ?? false;
        profile.name = prefs.getString('userName') ?? (currentUser?.displayName ?? '');
        profile.email = prefs.getString('userEmail') ?? (currentUser?.email ?? '');
        profile.photoUrl = prefs.getString('userPhoto') ?? '';
        profile.age = prefs.getInt('userAge') ?? 0;
        profile.weight = prefs.getDouble('userWeight') ?? 0.0;
        profile.height = prefs.getDouble('userHeight') ?? 0.0;
        profile.gender = prefs.getString('userGender') ?? 'Masculino';
        profile.goal = prefs.getString('userGoal') ?? 'Emagrecimento GLP-1';
        profile.injectionIntervalDays = prefs.getInt('userInterval') ?? 7;
        waterIntakeMl = prefs.getInt('waterIntake') ?? 0;
        consumedCalories = prefs.getInt('consumedCalories') ?? 0;

        final logsString = prefs.getString('injectionLogs');
        if (logsString != null && logsString.isNotEmpty) {
          final List decoded = jsonDecode(logsString);
          injectionLogs = decoded.map((e) => InjectionLog.fromJson(e)).toList();
        }

        final weightsString = prefs.getString('weightLogs');
        if (weightsString != null && weightsString.isNotEmpty) {
          final List decodedW = jsonDecode(weightsString);
          weightLogs = decodedW.map((e) => WeightLog.fromJson(e)).toList();
        }
      });
    } catch (e) {
      debugPrint("Erro ao carregar dados locais: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', profile.isLoggedIn);
    await prefs.setBool('isInitialSetupDone', profile.isInitialSetupDone);
    await prefs.setString('userName', profile.name);
    await prefs.setString('userEmail', profile.email);
    await prefs.setString('userPhoto', profile.photoUrl);
    await prefs.setInt('userAge', profile.age);
    await prefs.setDouble('userWeight', profile.weight);
    await prefs.setDouble('userHeight', profile.height);
    await prefs.setString('userGender', profile.gender);
    await prefs.setString('userGoal', profile.goal);
    await prefs.setInt('userInterval', profile.injectionIntervalDays);
    await prefs.setInt('waterIntake', waterIntakeMl);
    await prefs.setInt('consumedCalories', consumedCalories);

    final String encodedLogs = jsonEncode(injectionLogs.map((e) => e.toJson()).toList());
    await prefs.setString('injectionLogs', encodedLogs);

    final String encodedWeights = jsonEncode(weightLogs.map((e) => e.toJson()).toList());
    await prefs.setString('weightLogs', encodedWeights);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF0061A4)),
              SizedBox(height: 16),
              Text("Iniciando TirzeTrack...", style: TextStyle(color: Color(0xFF0061A4))),
            ],
          ),
        ),
      );
    }

    if (!profile.isLoggedIn && !profile.isInitialSetupDone) {
      return LoginScreen(
        onAuthSuccess: (User user) {
          setState(() {
            profile.isLoggedIn = true;
            profile.email = user.email ?? '';
            if (profile.name.isEmpty) {
              profile.name = user.email?.split('@').first ?? "Usuário";
            }
          });
          _saveUserData();
        },
        onSelectLocalAccount: () {
          setState(() {
            profile.isLoggedIn = true;
            if (profile.name.isEmpty) profile.name = "Conta Local";
          });
          _saveUserData();
        },
      );
    }

    if (!profile.isInitialSetupDone) {
      return OnboardingScreen(
        profile: profile,
        onComplete: () {
          setState(() {
            profile.isInitialSetupDone = true;
            if (profile.weight > 0 && weightLogs.isEmpty) {
              weightLogs.add(WeightLog(profile.weight, DateTime.now()));
            }
          });
          _saveUserData();
        },
      );
    }

    return MainNavigationScreen(
      profile: profile,
      waterIntakeMl: waterIntakeMl,
      waterGoalMl: waterGoalMl,
      consumedCalories: consumedCalories,
      injectionLogs: injectionLogs,
      weightLogs: weightLogs,
      onUpdateWater: (val) {
        setState(() => waterIntakeMl = val);
        _saveUserData();
      },
      onUpdateCalories: (val) {
        setState(() => consumedCalories = val);
        _saveUserData();
      },
      onAddInjection: (log) {
        setState(() => injectionLogs.add(log));
        _saveUserData();
      },
      onAddWeight: (w) {
        setState(() {
          profile.weight = w;
          weightLogs.add(WeightLog(w, DateTime.now()));
        });
        _saveUserData();
      },
      onLogout: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        try {
          await FirebaseAuth.instance.signOut();
        } catch (_) {}
        setState(() {
          profile.isLoggedIn = false;
          profile.isInitialSetupDone = false;
          profile.name = '';
          profile.email = '';
          profile.photoUrl = '';
          injectionLogs.clear();
          weightLogs.clear();
          waterIntakeMl = 0;
          consumedCalories = 0;
        });
      },
    );
  }
}

// -----------------------------------------------------------------------------
// TELA DE LOGIN
// -----------------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  final Function(User user) onAuthSuccess;
  final VoidCallback onSelectLocalAccount;

  const LoginScreen({
    super.key,
    required this.onAuthSuccess,
    required this.onSelectLocalAccount,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isAuthenticating = false;

  Future<void> _loginWithEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Informe o e-mail e a senha.');
      return;
    }

    setState(() => _isAuthenticating = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (credential.user != null) {
        widget.onAuthSuccess(credential.user!);
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Erro ao realizar login.');
    } catch (e) {
      _showError('Erro inesperado: $e');
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  Future<void> _signUpWithEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Informe o e-mail e a senha.');
      return;
    }

    setState(() => _isAuthenticating = true);
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (credential.user != null) {
        widget.onAuthSuccess(credential.user!);
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Erro ao criar conta.');
    } catch (e) {
      _showError('Erro inesperado: $e');
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Icon(Icons.vaccines, size: 80, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'TirzeTrack',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Acompanhamento Especializado em GLP-1',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 24),
                if (_isAuthenticating)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  FilledButton(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: _loginWithEmail,
                    child: const Text('ENTRAR COM E-MAIL', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: _signUpWithEmail,
                    child: const Text('CRIAR NOVA CONTA', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text('ou', style: TextStyle(color: Colors.grey)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Continuar sem Login (Conta Local)', style: TextStyle(fontSize: 15)),
                    onPressed: widget.onSelectLocalAccount,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ONBOARDING
// -----------------------------------------------------------------------------
class OnboardingScreen extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback onComplete;

  const OnboardingScreen({
    super.key,
    required this.profile,
    required this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuração do Perfil')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Ajuste do Seu Protocolo',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Calcularemos sua meta exata considerando a ação do tratamento GLP-1.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            TextFormField(
              initialValue: widget.profile.name,
              decoration: const InputDecoration(labelText: 'Seu Nome', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => v == null || v.isEmpty ? 'Informe seu nome' : null,
              onSaved: (val) => widget.profile.name = val ?? '',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Idade', prefixIcon: Icon(Icons.cake_outlined)),
                    validator: (v) => v == null || v.isEmpty ? 'Informe a idade' : null,
                    onSaved: (val) => widget.profile.age = int.tryParse(val ?? '') ?? 0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: widget.profile.gender,
                    decoration: const InputDecoration(labelText: 'Sexo'),
                    items: ['Masculino', 'Feminino']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => widget.profile.gender = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Peso (kg)', prefixIcon: Icon(Icons.scale_outlined)),
                    validator: (v) => v == null || v.isEmpty ? 'Informe o peso' : null,
                    onSaved: (val) => widget.profile.weight = double.tryParse(val?.replaceAll(',', '.') ?? '') ?? 0.0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Altura (cm)', prefixIcon: Icon(Icons.height_outlined)),
                    validator: (v) => v == null || v.isEmpty ? 'Informe a altura' : null,
                    onSaved: (val) => widget.profile.height = double.tryParse(val?.replaceAll(',', '.') ?? '') ?? 0.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: widget.profile.goal,
              decoration: const InputDecoration(labelText: 'Objetivo de Calorias', prefixIcon: Icon(Icons.flag_outlined)),
              items: const [
                DropdownMenuItem(
                  value: 'Emagrecimento GLP-1',
                  child: Text('Emagrecimento GLP-1 (Déficit)', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: 'Perda Gradual',
                  child: Text('Perda Gradual (Déficit Leve)', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: 'Manutenção',
                  child: Text('Manutenção do Peso', overflow: TextOverflow.ellipsis),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => widget.profile.goal = val);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              isExpanded: true,
              value: widget.profile.injectionIntervalDays,
              decoration: const InputDecoration(
                labelText: 'Frequência das Injeções',
                prefixIcon: Icon(Icons.repeat),
              ),
              items: const [
                DropdownMenuItem(value: 7, child: Text('A cada 7 dias (Semanal)', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 14, child: Text('A cada 14 dias (Quinzenal)', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 30, child: Text('A cada 30 dias (Mensal)', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (val) {
                if (val != null) setState(() => widget.profile.injectionIntervalDays = val);
              },
            ),
            const SizedBox(height: 28),
            FilledButton(
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();
                  widget.onComplete();
                }
              },
              child: const Text('Salvar e Calcular Meta', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// NAVEGAÇÃO PRINCIPAL
// -----------------------------------------------------------------------------
class MainNavigationScreen extends StatefulWidget {
  final UserProfile profile;
  final int waterIntakeMl;
  final int waterGoalMl;
  final int consumedCalories;
  final List<InjectionLog> injectionLogs;
  final List<WeightLog> weightLogs;

  final Function(int) onUpdateWater;
  final Function(int) onUpdateCalories;
  final Function(InjectionLog) onAddInjection;
  final Function(double) onAddWeight;
  final VoidCallback onLogout;

  const MainNavigationScreen({
    super.key,
    required this.profile,
    required this.waterIntakeMl,
    required this.waterGoalMl,
    required this.consumedCalories,
    required this.injectionLogs,
    required this.weightLogs,
    required this.onUpdateWater,
    required this.onUpdateCalories,
    required this.onAddInjection,
    required this.onAddWeight,
    required this.onLogout,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(
        profile: widget.profile,
        waterIntake: widget.waterIntakeMl,
        waterGoal: widget.waterGoalMl,
        consumedCalories: widget.consumedCalories,
        lastInjection: widget.injectionLogs.isNotEmpty ? widget.injectionLogs.last : null,
      ),
      InjectionsScreen(
        logs: widget.injectionLogs,
        onAddLog: widget.onAddInjection,
      ),
      NutritionScreen(
        dailyGoal: widget.profile.dailyCalories.round(),
        consumedCalories: widget.consumedCalories,
        onAddCalories: (cals) => widget.onUpdateCalories(widget.consumedCalories + cals),
      ),
      WaterScreen(
        currentWater: widget.waterIntakeMl,
        goalWater: widget.waterGoalMl,
        onAddWater: (amount) => widget.onUpdateWater(widget.waterIntakeMl + amount),
      ),
      EvolutionScreen(
        weightLogs: widget.weightLogs,
        currentWeight: widget.profile.weight,
        onAddWeight: widget.onAddWeight,
      ),
      ProfileScreen(
        profile: widget.profile,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.vaccines_outlined), selectedIcon: Icon(Icons.vaccines), label: 'Injeção'),
          NavigationDestination(icon: Icon(Icons.restaurant_outlined), selectedIcon: Icon(Icons.restaurant), label: 'Dieta'),
          NavigationDestination(icon: Icon(Icons.local_drink_outlined), selectedIcon: Icon(Icons.local_drink), label: 'Água'),
          NavigationDestination(icon: Icon(Icons.show_chart_outlined), selectedIcon: Icon(Icons.show_chart), label: 'Evolução'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// DASHBOARD
// -----------------------------------------------------------------------------
class HomeScreen extends StatelessWidget {
  final UserProfile profile;
  final int waterIntake;
  final int waterGoal;
  final int consumedCalories;
  final InjectionLog? lastInjection;

  const HomeScreen({
    super.key,
    required this.profile,
    required this.waterIntake,
    required this.waterGoal,
    required this.consumedCalories,
    this.lastInjection,
  });

  String _calculateNextInjectionTimer() {
    if (lastInjection == null) return "Nenhuma injeção registrada";

    final nextDate = lastInjection!.dateTime.add(Duration(days: profile.injectionIntervalDays));
    final diff = nextDate.difference(DateTime.now());

    if (diff.isNegative) {
      return "Aplicação pendente!";
    }

    final days = diff.inDays;
    final hours = diff.inHours % 24;
    return "Próxima em: $days dias e $hours horas";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (profile.photoUrl.isNotEmpty)
              CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(profile.photoUrl),
              )
            else
              const Icon(Icons.account_circle, size: 32),
            const SizedBox(width: 10),
            Expanded(child: Text('Olá, ${profile.name.isEmpty ? "Usuário" : profile.name}', overflow: TextOverflow.ellipsis)),
          ],
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, color: theme.colorScheme.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Text('Cronômetro de Aplicação', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _calculateNextInjectionTimer(),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Intervalo definido: A cada ${profile.injectionIntervalDays} dias',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Meta Calórica Ajustada', style: TextStyle(fontWeight: FontWeight.bold)),
                      Chip(
                        label: Text(profile.goal, style: const TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      )
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${profile.dailyCalories.round()} kcal / dia', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('IMC: ${profile.imc.toStringAsFixed(1)}'),
                      Text('Status: ${profile.imcClassification}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.restaurant, color: Colors.orange),
                        const SizedBox(height: 8),
                        const Text('Calorias Hoje'),
                        Text('$consumedCalories / ${profile.dailyCalories.round()} kcal', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.local_drink, color: Colors.blue),
                        const SizedBox(height: 8),
                        const Text('Água Consumida'),
                        Text('$waterIntake / $waterGoal ml', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// NUTRIÇÃO COM IA GEMINI REAL
// -----------------------------------------------------------------------------
class NutritionScreen extends StatefulWidget {
  final int dailyGoal;
  final int consumedCalories;
  final Function(int) onAddCalories;

  const NutritionScreen({
    super.key,
    required this.dailyGoal,
    required this.consumedCalories,
    required this.onAddCalories,
  });

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  File? _capturedImage;
  final ImagePicker _picker = ImagePicker();

  final String _geminiApiKey = 'AQ.Ab8RN6JTJ1VtAxx0HyOYx4NoAqjqAd7oEpv9aSonBu2DS8V2PA';

  Future<void> _takeMealPhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      imageQuality: 80,
    );

    if (photo != null) {
      setState(() {
        _capturedImage = File(photo.path);
      });
      _analyzeImageWithGemini(File(photo.path));
    }
  }

  Future<void> _analyzeImageWithGemini(File imageFile) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF0061A4)),
            SizedBox(height: 16),
            Text("IA do Gemini analisando os alimentos...", textAlign: TextAlign.center),
          ],
        ),
      ),
    );

    try {
      final bytes = await imageFile.readAsBytes();
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _geminiApiKey,
      );

      final prompt = TextPart(
        'Analise esta foto de refeição. Identifique os alimentos presentes e estime as calorias totais. '
        'Responda estritamente em formato JSON válido com a estrutura: '
        '{"prato": "nome simples", "calorias": 450, "detalhes": "ingredientes"}'
      );

      final imagePart = DataPart('image/jpeg', bytes);
      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      if (mounted) Navigator.pop(context);

      final responseText = response.text;
      if (responseText != null) {
        String cleanJson = responseText;
        cleanJson = cleanJson.replaceAll('```json', '');
        cleanJson = cleanJson.replaceAll('
