import 'package:flutter/material.dart';

void main() {
  runApp(const HealthTrackApp());
}

class HealthTrackApp extends StatelessWidget {
  const HealthTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TirzeTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006C50),
          brightness: Brightness.light,
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
  int age;
  double weight; // kg
  double height; // cm
  String gender; // 'Masculino' ou 'Feminino'
  String activityLevel;
  bool isInitialSetupDone;

  UserProfile({
    this.name = '',
    this.age = 0,
    this.weight = 0.0,
    this.height = 0.0,
    this.gender = 'Masculino',
    this.activityLevel = 'Moderado',
    this.isInitialSetupDone = false,
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

  // Cálculo da Taxa Metabólica Basal (Harris-Benedict)
  double get tbm {
    if (weight <= 0 || height <= 0 || age <= 0) return 0.0;
    if (gender == 'Masculino') {
      return 88.36 + (13.4 * weight) + (4.8 * height) - (5.7 * age);
    } else {
      return 447.6 + (9.2 * weight) + (3.1 * height) - (4.3 * age);
    }
  }

  double get dailyCalories {
    double factor = 1.2;
    if (activityLevel == 'Leve') factor = 1.375;
    if (activityLevel == 'Moderado') factor = 1.55;
    if (activityLevel == 'Intenso') factor = 1.725;
    return tbm * factor;
  }
}

class InjectionLog {
  final String medication;
  final String dose;
  final String site;
  final DateTime date;

  InjectionLog({
    required this.medication,
    required this.dose,
    required this.site,
    required this.date,
  });
}

class WeightLog {
  final double weight;
  final DateTime date;

  WeightLog(this.weight, this.date);
}

class FoodItem {
  final String name;
  final int calories;

  FoodItem(this.name, this.calories);
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
  int waterIntakeMl = 0;
  final int waterGoalMl = 2500;
  int consumedCalories = 0;

  final List<InjectionLog> injectionLogs = [];
  final List<WeightLog> weightLogs = [];

  void _completeInitialSetup() {
    setState(() {
      profile.isInitialSetupDone = true;
      if (profile.weight > 0) {
        weightLogs.add(WeightLog(profile.weight, DateTime.now()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!profile.isInitialSetupDone) {
      return OnboardingScreen(
        profile: profile,
        onComplete: _completeInitialSetup,
      );
    }

    return MainNavigationScreen(
      profile: profile,
      waterIntakeMl: waterIntakeMl,
      waterGoalMl: waterGoalMl,
      consumedCalories: consumedCalories,
      injectionLogs: injectionLogs,
      weightLogs: weightLogs,
      onUpdateWater: (val) => setState(() => waterIntakeMl = val),
      onUpdateCalories: (val) => setState(() => consumedCalories = val),
      onAddInjection: (log) => setState(() => injectionLogs.add(log)),
      onAddWeight: (w) {
        setState(() {
          profile.weight = w;
          weightLogs.add(WeightLog(w, DateTime.now()));
        });
      },
    );
  }
}

// -----------------------------------------------------------------------------
// TELA DE CADASTRO INICIAL (ONBOARDING)
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
      appBar: AppBar(
        title: const Text('TirzeTrack'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.health_and_safety, size: 70, color: Color(0xFF006C50)),
            const SizedBox(height: 12),
            const Text(
              'Bem-vindo ao TirzeTrack',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure seu perfil inicial para calcularmos seu IMC e metas calóricas diárias.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Seu Nome',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Informe seu nome' : null,
              onSaved: (val) => widget.profile.name = val ?? '',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Idade',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.cake),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Informe a idade' : null,
                    onSaved: (val) => widget.profile.age = int.tryParse(val ?? '') ?? 0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: widget.profile.gender,
                    decoration: const InputDecoration(
                      labelText: 'Sexo',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Masculino', 'Feminino']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
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
                    decoration: const InputDecoration(
                      labelText: 'Peso Atual (kg)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.monitor_weight),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Informe o peso' : null,
                    onSaved: (val) =>
                        widget.profile.weight = double.tryParse(val?.replaceAll(',', '.') ?? '') ?? 0.0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Altura (cm)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.height),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Informe a altura' : null,
                    onSaved: (val) =>
                        widget.profile.height = double.tryParse(val?.replaceAll(',', '.') ?? '') ?? 0.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: widget.profile.activityLevel,
              decoration: const InputDecoration(
                labelText: 'Nível de Atividade Física',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.fitness_center),
              ),
              items: ['Sedentário', 'Leve', 'Moderado', 'Intenso']
                  .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => widget.profile.activityLevel = val);
              },
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006C50),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    widget.onComplete();
                  }
                },
                child: const Text('Salvar e Entrar no TirzeTrack', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// NAVEGAÇÃO PRINCIPAL (DASHBOARD)
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
        onUpdate: () => setState(() {}),
      ),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.vaccines_rounded), label: 'Injeção'),
          NavigationDestination(icon: Icon(Icons.restaurant_rounded), label: 'Dieta'),
          NavigationDestination(icon: Icon(Icons.local_drink_rounded), label: 'Água'),
          NavigationDestination(icon: Icon(Icons.show_chart_rounded), label: 'Evolução'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Perfil'),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 1. TELA INICIAL (DASHBOARD)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('TirzeTrack - Olá, ${profile.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Card IMC/Calorias
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Meta Calórica Diária',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    '${profile.dailyCalories.round()} kcal / dia',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
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

          // Resumo da Injeção
          Card(
            child: ListTile(
              leading: const Icon(Icons.vaccines, color: Colors.teal, size: 36),
              title: const Text('Última Aplicação'),
              subtitle: lastInjection != null
                  ? Text('${lastInjection!.medication} (${lastInjection!.dose}) - ${lastInjection!.site}')
                  : const Text('Nenhuma aplicação registrada ainda.'),
            ),
          ),
          const SizedBox(height: 12),

          // Resumo Nutrição e Água
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
                        Text(
                          '$consumedCalories / ${profile.dailyCalories.round()} kcal',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
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
                        Text(
                          '$waterIntake / $waterGoal ml',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
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
// 2. TELA DE PERFIL / EDIÇÃO
// -----------------------------------------------------------------------------
class ProfileScreen extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback onUpdate;

  const ProfileScreen({super.key, required this.profile, required this.onUpdate});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil e Dados')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              initialValue: widget.profile.name,
              decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
              onChanged: (val) => widget.profile.name = val,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: widget.profile.age.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Idade', border: OutlineInputBorder()),
                    onChanged: (val) => widget.profile.age = int.tryParse(val) ?? widget.profile.age,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: widget.profile.gender,
                    decoration: const InputDecoration(labelText: 'Sexo', border: OutlineInputBorder()),
                    items: ['Masculino', 'Feminino']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
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
                    initialValue: widget.profile.weight.toString(),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Peso (kg)', border: OutlineInputBorder()),
                    onChanged: (val) =>
                        widget.profile.weight = double.tryParse(val.replaceAll(',', '.')) ?? widget.profile.weight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: widget.profile.height.toString(),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Altura (cm)', border: OutlineInputBorder()),
                    onChanged: (val) =>
                        widget.profile.height = double.tryParse(val.replaceAll(',', '.')) ?? widget.profile.height,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: widget.profile.activityLevel,
              decoration: const InputDecoration(labelText: 'Nível de Atividade Física', border: OutlineInputBorder()),
              items: ['Sedentário', 'Leve', 'Moderado', 'Intenso']
                  .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => widget.profile.activityLevel = val);
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              onPressed: () {
                widget.onUpdate();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Perfil atualizado com sucesso!')),
                );
              },
              child: const Text('Salvar Alterações'),
            )
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. TELA DE INJEÇÃO E MAPA CORPORAL CUSTOMIZADO
// -----------------------------------------------------------------------------
class InjectionsScreen extends StatefulWidget {
  final List<InjectionLog> logs;
  final Function(InjectionLog) onAddLog;

  const InjectionsScreen({super.key, required this.logs, required this.onAddLog});

  @override
  State<InjectionsScreen> createState() => _InjectionsScreenState();
}

class _InjectionsScreenState extends State<InjectionsScreen> {
  String selectedMed = 'Tirzepatida';
  String selectedDose = '2.5 mg';
  String selectedSite = 'Abdômen Direito';

  final List<String> meds = ['Tirzepatida', 'Retatrutida', 'Semaglutida'];
  final List<String> sites = [
    'Abdômen Direito',
    'Abdômen Esquerdo',
    'Coxa Direita',
    'Coxa Esquerda',
    'Braço Direito',
    'Braço Esquerdo'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro de Injeção')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: selectedMed,
              decoration: const InputDecoration(labelText: 'Medicamento', border: OutlineInputBorder()),
              items: meds.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setState(() => selectedMed = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: selectedDose,
              decoration: const InputDecoration(labelText: 'Dose (ex: 2.5 mg, 0.5 mg)', border: OutlineInputBorder()),
              onChanged: (v) => selectedDose = v,
            ),
            const SizedBox(height: 16),
            const Text('Selecione o Local de Aplicação:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            // Mapa Corporal Visual com Gráfico + Silhueta + Injeção
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(16),
                color: Colors.teal.shade50.withOpacity(0.3),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 120,
                    width: 120,
                    child: CustomPaint(
                      painter: BodySyringeGraphPainter(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: sites.map((site) {
                      final isSelected = selectedSite == site;
                      return ChoiceChip(
                        label: Text(site),
                        selected: isSelected,
                        selectedColor: const Color(0xFF006C50),
                        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                        onSelected: (sel) {
                          if (sel) setState(() => selectedSite = site);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Registrar Aplicação'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006C50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
                onPressed: () {
                  final log = InjectionLog(
                    medication: selectedMed,
                    dose: selectedDose,
                    site: selectedSite,
                    date: DateTime.now(),
                  );
                  widget.onAddLog(log);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Aplicação registrada com sucesso!')),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const Text('Histórico de Aplicações', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            widget.logs.isEmpty
                ? const Text('Nenhuma aplicação registrada.', style: TextStyle(color: Colors.grey))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.logs.length,
                    itemBuilder: (context, index) {
                      final item = widget.logs.reversed.toList()[index];
                      return ListTile(
                        leading: const Icon(Icons.check_circle, color: Colors.teal),
                        title: Text('${item.medication} - ${item.dose}'),
                        subtitle: Text(
                            'Local: ${item.site} | Data: ${item.date.day}/${item.date.month}/${item.date.year}'),
                      );
                    },
                  )
          ],
        ),
      ),
    );
  }
}

// Custom Painter para desenhar Gráfico ao Fundo + Silhueta do Corpo + Seringa/Injeção
class BodySyringeGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // 1. Gráfico ao fundo (Linha de progresso)
    final Paint graphPaint = Paint()
      ..color = Colors.teal.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final Path graphPath = Path()
      ..moveTo(0, h * 0.7)
      ..quadraticBezierTo(w * 0.25, h * 0.4, w * 0.5, h * 0.6)
      ..quadraticBezierTo(w * 0.75, h * 0.8, w, h * 0.25);

    canvas.drawPath(graphPath, graphPaint);

    // 2. Silhueta do corpo (Centro)
    final Paint bodyPaint = Paint()
      ..color = const Color(0xFF006C50).withOpacity(0.85)
      ..style = PaintingStyle.fill;

    // Cabeça
    canvas.drawCircle(Offset(w * 0.42, h * 0.22), w * 0.09, bodyPaint);

    // Tronco e Pernas
    final Path bodyPath = Path()
      ..moveTo(w * 0.35, h * 0.33)
      ..lineTo(w * 0.49, h * 0.33)
      ..lineTo(w * 0.47, h * 0.65)
      ..lineTo(w * 0.43, h * 0.90)
      ..lineTo(w * 0.40, h * 0.90)
      ..lineTo(w * 0.42, h * 0.65)
      ..lineTo(w * 0.37, h * 0.65)
      ..lineTo(w * 0.35, h * 0.90)
      ..lineTo(w * 0.32, h * 0.90)
      ..lineTo(w * 0.34, h * 0.65)
      ..close();

    canvas.drawPath(bodyPath, bodyPaint);

    // 3. Seringa / Injeção (Sobreposta)
    final Paint syringePaint = Paint()
      ..color = Colors.teal.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Corpo da Seringa
    canvas.drawRect(Rect.fromLTWH(w * 0.58, h * 0.35, w * 0.22, h * 0.12), syringePaint);
    // Agulha
    canvas.drawLine(Offset(w * 0.58, h * 0.41), Offset(w * 0.48, h * 0.41), syringePaint);
    // Êmbolo
    canvas.drawLine(Offset(w * 0.80, h * 0.41), Offset(w * 0.90, h * 0.41), syringePaint);
    canvas.drawLine(Offset(w * 0.90, h * 0.36), Offset(w * 0.90, h * 0.46), syringePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -----------------------------------------------------------------------------
// 4. TELA DE CONSUMO DE ÁGUA
// -----------------------------------------------------------------------------
class WaterScreen extends StatelessWidget {
  final int currentWater;
  final int goalWater;
  final Function(int) onAddWater;

  const WaterScreen({
    super.key,
    required this.currentWater,
    required this.goalWater,
    required this.onAddWater,
  });

  @override
  Widget build(BuildContext context) {
    double progress = (currentWater / goalWater).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(title: const Text('Registro de Água')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.water_drop, size: 80, color: Colors.blue.shade400),
            const SizedBox(height: 16),
            Text('$currentWater / $goalWater ml', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress, minHeight: 12),
            const SizedBox(height: 32),
            const Text('Adicionar Tomada:'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: () => onAddWater(200), child: const Text('+ 200 ml')),
                ElevatedButton(onPressed: () => onAddWater(350), child: const Text('+ 350 ml')),
                ElevatedButton(onPressed: () => onAddWater(500), child: const Text('+ 500 ml')),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 5. TELA DE ALIMENTAÇÃO E FOTO IA
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
  final List<FoodItem> commonFoods = [
    FoodItem('Prato Feito (Arroz, Feijão, Frango, Salada)', 550),
    FoodItem('Ovo Cozido (1un)', 70),
    FoodItem('Pão Integral com Queijo', 200),
    FoodItem('Salada Caesar com Grelhado', 350),
    FoodItem('Shake de Proteína (Whey)', 150),
  ];

  void _simulateAiPhotoScanner() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_enhance, size: 60, color: Colors.purple),
            const SizedBox(height: 12),
            const Text('Escaneando Refeição por IA...', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            FutureBuilder(
              future: Future.delayed(const Duration(seconds: 2), () => true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Column(
                    children: [
                      const Text('IA Identificou: Prato Saudável (Grelhado + Legumes) ~ 420 kcal'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          widget.onAddCalories(420);
                          Navigator.pop(context);
                        },
                        child: const Text('Adicionar 420 kcal à meta'),
                      )
                    ],
                  );
                }
                return const Text('Analisando imagem...');
              },
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double progress = widget.dailyGoal > 0 ? (widget.consumedCalories / widget.dailyGoal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Alimentação e Calorias')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('Consumido: ${widget.consumedCalories} / ${widget.dailyGoal} kcal'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade50,
              padding: const EdgeInsets.all(16),
            ),
            icon: const Icon(Icons.camera_alt, color: Colors.purple),
            label: const Text('Tirar Foto da Refeição (Calcular via IA)'),
            onPressed: _simulateAiPhotoScanner,
          ),
          const SizedBox(height: 24),
          const Text('Alimentos Rápidos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          ...commonFoods.map((food) => ListTile(
                title: Text(food.name),
                subtitle: Text('${food.calories} kcal'),
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                  onPressed: () {
                    widget.onAddCalories(food.calories);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${food.name} adicionado!')),
                    );
                  },
                ),
              )),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 6. TELA DE EVOLUÇÃO (PESO)
// -----------------------------------------------------------------------------
class EvolutionScreen extends StatelessWidget {
  final List<WeightLog> weightLogs;
  final double currentWeight;
  final Function(double) onAddWeight;

  const EvolutionScreen({
    super.key,
    required this.weightLogs,
    required this.currentWeight,
    required this.onAddWeight,
  });

  @override
  Widget build(BuildContext context) {
    final textController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Evolução do Peso')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Peso Atual:', style: TextStyle(fontSize: 18)),
                  Text('$currentWeight kg', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: textController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Novo Peso (kg)', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final val = double.tryParse(textController.text.replaceAll(',', '.'));
                  if (val != null) {
                    onAddWeight(val);
                    textController.clear();
                  }
                },
                child: const Text('Registrar'),
              )
            ],
          ),
          const SizedBox(height: 24),
          const Text('Histórico de Pesagem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          weightLogs.isEmpty
              ? const Text('Nenhum histórico registrado ainda.', style: TextStyle(color: Colors.grey))
              : Column(
                  children: weightLogs.reversed
                      .map(
                        (log) => ListTile(
                          leading: const Icon(Icons.monitor_weight),
                          title: Text('${log.weight} kg'),
                          subtitle: Text('Data: ${log.date.day}/${log.date.month}/${log.date.year}'),
                        ),
                      )
                      .toList(),
                ),
        ],
      ),
    );
  }
}
