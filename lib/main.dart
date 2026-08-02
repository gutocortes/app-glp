import 'package:flutter/material.dart';

void main() {
  runApp(const HealthTrackApp());
}

class HealthTrackApp extends StatelessWidget {
  const HealthTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Acompanhamento GLP-1',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006C50),
          brightness: Brightness.light,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// MODELOS DE DADOS E ESTADO GLOBAL
// -----------------------------------------------------------------------------
class UserProfile {
  String name;
  int age;
  double weight; // kg
  double height; // cm
  String gender; // 'Masculino' ou 'Feminino'
  String activityLevel;

  UserProfile({
    this.name = 'Usuário',
    this.age = 30,
    this.weight = 85.0,
    this.height = 175.0,
    this.gender = 'Masculino',
    this.activityLevel = 'Moderado',
  });

  double get imc => weight / ((height / 100) * (height / 100));

  String get imcClassification {
    double val = imc;
    if (val < 18.5) return 'Abaixo do peso';
    if (val < 25.0) return 'Peso normal';
    if (val < 30.0) return 'Sobrepeso';
    if (val < 35.0) return 'Obesidade Grau I';
    if (val < 40.0) return 'Obesidade Grau II';
    return 'Obesidade Grau III';
  }

  // Cálculo da Taxa Metabólica Basal (Harris-Benedict)
  double get tbm {
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
// NAVEGAÇÃO PRINCIPAL
// -----------------------------------------------------------------------------
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // Estado Compartilhado
  final UserProfile profile = UserProfile();
  int waterIntakeMl = 1250;
  final int waterGoalMl = 2500;
  int consumedCalories = 850;

  final List<InjectionLog> injectionLogs = [
    InjectionLog(
      medication: 'Tirzepatida',
      dose: '2.5 mg',
      site: 'Abdômen Direito',
      date: DateTime.now().subtract(const Duration(days: 7)),
    ),
  ];

  final List<WeightLog> weightLogs = [
    WeightLog(90.0, DateTime.now().subtract(const Duration(days: 30))),
    WeightLog(87.5, DateTime.now().subtract(const Duration(days: 15))),
    WeightLog(85.0, DateTime.now()),
  ];

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(
        profile: profile,
        waterIntake: waterIntakeMl,
        waterGoal: waterGoalMl,
        consumedCalories: consumedCalories,
        lastInjection: injectionLogs.isNotEmpty ? injectionLogs.last : null,
      ),
      InjectionsScreen(
        logs: injectionLogs,
        onAddLog: (log) {
          setState(() {
            injectionLogs.add(log);
          });
        },
      ),
      NutritionScreen(
        dailyGoal: profile.dailyCalories.round(),
        consumedCalories: consumedCalories,
        onAddCalories: (cals) {
          setState(() {
            consumedCalories += cals;
          });
        },
      ),
      WaterScreen(
        currentWater: waterIntakeMl,
        goalWater: waterGoalMl,
        onAddWater: (amount) {
          setState(() {
            waterIntakeMl += amount;
          });
        },
      ),
      EvolutionScreen(
        weightLogs: weightLogs,
        currentWeight: profile.weight,
        onAddWeight: (w) {
          setState(() {
            profile.weight = w;
            weightLogs.add(WeightLog(w, DateTime.now()));
          });
        },
      ),
      ProfileScreen(
        profile: profile,
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
      appBar: AppBar(title: Text('Olá, ${profile.name}')),
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
                  : const Text('Nenhuma aplicação registrada.'),
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
// 2. TELA DE PERFIL / CADASTRO
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
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Peso (kg)', border: OutlineInputBorder()),
                    onChanged: (val) => widget.profile.weight = double.tryParse(val) ?? widget.profile.weight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: widget.profile.height.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Altura (cm)', border: OutlineInputBorder()),
                    onChanged: (val) => widget.profile.height = double.tryParse(val) ?? widget.profile.height,
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
                  const SnackBar(content: Text('Dados atualizados com sucesso!')),
                );
              },
              child: const Text('Salvar e Recalcular Metas'),
            )
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. TELA DE INJEÇÃO E MAPA CORPORAL
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

            // Mapa Corporal Visual Simplificado
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade50,
              ),
              child: Column(
                children: [
                  const Icon(Icons.accessibility_new, size: 100, color: Colors.teal),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: sites.map((site) {
                      final isSelected = selectedSite == site;
                      return ChoiceChip(
                        label: Text(site),
                        selected: isSelected,
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
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
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
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.logs.length,
              itemBuilder: (context, index) {
                final item = widget.logs.reversed.toList()[index];
                return ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.teal),
                  title: Text('${item.medication} - ${item.dose}'),
                  subtitle: Text('Local: ${item.site} | Data: ${item.date.day}/${item.date.month}/${item.date.year}'),
                );
              },
            )
          ],
        ),
      ),
    );
  }
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
// 5. TELA DE NUTRITION / ALIMENTAÇÃO E FOTO IA
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
                  LinearProgressIndicator(
                    value: (widget.consumedCalories / widget.dailyGoal).clamp(0.0, 1.0),
                  ),
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
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Novo Peso (kg)', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final val = double.tryParse(textController.text);
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
          ...weightLogs.reversed.map(
            (log) => ListTile(
              leading: const Icon(Icons.monitor_weight),
              title: Text('${log.weight} kg'),
              subtitle: Text('Data: ${log.date.day}/${log.date.month}/${log.date.year}'),
            ),
          ),
        ],
      ),
    );
  }
}
