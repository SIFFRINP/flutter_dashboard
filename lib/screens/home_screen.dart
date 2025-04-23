import 'package:flutter/material.dart';
import 'map_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import 'dart:async'; //LA
import 'package:flutter/services.dart' show rootBundle; //LA

class InteractiveCard extends StatefulWidget {
  final String title;
  final Color color;
  final IconData icon;
  final double height;

  const InteractiveCard({
    Key? key,
    required this.title,
    required this.color,
    required this.icon,
    this.height = 28.0,
  }) : super(key: key);

  @override
  State<InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<InteractiveCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: TweenAnimationBuilder(
        duration: const Duration(milliseconds: 200),
        tween: Tween<double>(begin: 1.0, end: isHovered ? 1.1 : 1.0),
        builder: (context, double value, child) {
          return Transform.scale(
            scale: value,
            alignment: Alignment.center,
            child: Container(
              height: widget.height,
              width: 180,
              margin: const EdgeInsets.symmetric(vertical: 1),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.3),
                    blurRadius: isHovered ? 8 : 6,
                    offset: Offset(0, isHovered ? 4 : 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.icon,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  String? selectedStationName;
  String? selectedParametreCode;
  List<String> _anecdotes = []; 
  String _currentAnecdote = ""; 
  int _currentIndex = 0; 
  Timer? _anecdoteTimer; 
  Map<String, dynamic>? selectedStationData;
  List<Map<String, dynamic>> _donneesParametre = [];
  Map<String, String> parametres = {
    '1301': 'Température (°C)',
    '1302': 'Ammonium (mg/L)',
    '1303': 'Nitrates (mg/L)',
    '1304': 'Oxygène dissous (mg/L)',
    '1305': 'pH',
    '1306': 'Phosphates (mg/L)',
    '1307': 'Carbone Organique (mg/L)',
    '1309': 'Demande Biochimique en oxygène (mg(O2)/L)'
  };
  Map<String, bool> parametresDisponibles = {};
  int touchedIndex = -1;
  Map<int, double> barWidths = {};
  AnimationController? _animationController;

  @override
  void initState() {
    super.initState();
    _initializeAnimationController();
    _loadAnecdotes(); 
  }

  Future<void> _loadAnecdotes() async {
    final String content = await rootBundle.loadString('assets/anecdotes.txt');
    setState(() {
      _anecdotes =
          content.split('\n').where((line) => line.trim().isNotEmpty).toList();
      _currentAnecdote = _anecdotes.isNotEmpty ? _anecdotes[0] : '';
    });
    _startAnecdoteTimer();
  }

  void _startAnecdoteTimer() {
    _anecdoteTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _anecdotes.length;
        _currentAnecdote = _anecdotes[_currentIndex];
      });
    });
  }

  void _initializeAnimationController() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController?.addListener(() {
      if (barWidths.isNotEmpty) {
        setState(() {
          Map<int, double> newBarWidths = Map.from(barWidths);
          barWidths.forEach((key, value) {
            if (key != touchedIndex) {
              double newWidth =
                  2 + (value - 2) * (1 - (_animationController?.value ?? 0));
              if (newWidth <= 2.1) {
                newBarWidths.remove(key);
              } else {
                newBarWidths[key] = newWidth;
              }
            }
          });
          barWidths = newBarWidths;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _anecdoteTimer?.cancel();
    super.dispose();
  }

  Future<void> _verifierParametresDisponibles() async {
    if (selectedStationData == null ||
        selectedStationData!['code_station'] == null) return;

    parametresDisponibles.clear();
    String codeStation = selectedStationData!['code_station'];
    String? premierParametreDisponible;

    for (var codeParam in parametres.keys) {
      try {
        final data =
            await ApiService.fetchStationParaDuree(codeStation, codeParam);
        parametresDisponibles[codeParam] = (data != null && data.isNotEmpty);

        // On garde une trace du premier paramètre disponible
        if (premierParametreDisponible == null &&
            parametresDisponibles[codeParam]!) {
          premierParametreDisponible = codeParam;
        }
      } catch (e) {
        print("Erreur lors de la vérification du paramètre $codeParam : $e");
        parametresDisponibles[codeParam] = false;
      }
    }

    setState(() {
      // On sélectionne automatiquement le premier paramètre disponible
      selectedParametreCode = premierParametreDisponible;
    });

    // Si on a trouvé un paramètre disponible, on charge ses données
    if (premierParametreDisponible != null) {
      await _chargerDonneesParametre();
    }
  }

  Future<void> _chargerDonneesParametre() async {
    if (selectedStationData == null ||
        selectedStationData!['code_station'] == null ||
        selectedParametreCode == null) return;

    try {
      final data = await ApiService.fetchStationParaDuree(
          selectedStationData!['code_station'], selectedParametreCode!);

      setState(() {
        if (data != null) {
          _donneesParametre = List<Map<String, dynamic>>.from(data);
          _donneesParametre.sort((a, b) =>
              DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
          // On garde uniquement les 20 dernières mesures
          if (_donneesParametre.length > 50) {
            _donneesParametre =
                _donneesParametre.sublist(_donneesParametre.length - 50);
          }
        } else {
          _donneesParametre.clear();
        }
      });
    } catch (e) {
      print("Erreur lors du chargement des données du paramètre : $e");
      setState(() {
        _donneesParametre.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
     final cleanedStationName = selectedStationName
                           ?.replaceAll(RegExp(r'\d+$'), '') // supprime les chiffres à la fin
                            .trim();
    return Scaffold(
      backgroundColor: const Color(0xFFeff3f8),
      body: SafeArea(
        child: Row(
          children: [
            // Card verticale à gauche
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                color: const Color(0xFFE4EEF3),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Container(
                  width: 250,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4EEF3),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFFbebebe),
                        offset: Offset(15, 15),
                        blurRadius: 30,
                      ),
                      BoxShadow(
                        color: Colors.white,
                        offset: Offset(-15, -15),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "Qualité de l'eau des rivières en France",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4a90e2),
                          ),
                        ),

                        // Image de la mascotte
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Center(
                            child: Transform.translate(
                              offset: Offset(-18, 0), // Décale de 20 pixels vers la gauche
                              child: Image.asset(
                                'assets/mascotte.png',
                                height: 125,
                                fit: BoxFit.contain,
                              ),
                            ),
                          )
                        ),
                        // const SizedBox(height: 2),

                        SizedBox(
                          height: 240,
                          child: Card(
                            color: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0xFFbebebe),
                                    offset: Offset(15, 15),
                                    blurRadius: 30,
                                  ),
                                  BoxShadow(
                                    color: Colors.white,
                                    offset: Offset(-15, -15),
                                    blurRadius: 30,
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE4EEF3),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.info_outline,
                                            color: Colors.blue[700],
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Informations',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    const Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Total stations : ',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ),
                                            Text(
                                              '24 180',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              'Total rivières : ',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ),
                                            Text(
                                              '3 224',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              'Données disponibles : ',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ),
                                            Text(
                                              '1960-2025',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Center(
                                      child: Column(
                                        children: [
                                          InteractiveCard(
                                            title: 'pH moyen : 7.53',
                                            color: Color(0xFF4a90e2),
                                            icon: Icons.bubble_chart,
                                            height: 35,
                                          ),
                                          SizedBox(height: 6),
                                          InteractiveCard(
                                            title:
                                                'Température moyenne : 13.1°C',
                                            color: Color(0xFF4a90e2),
                                            icon: Icons.thermostat,
                                            height: 35,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 7),

                        SizedBox(
                          height: 100,
                          child: Card(
                            color: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0xFFbebebe),
                                    offset: Offset(15, 15),
                                    blurRadius: 30,
                                  ),
                                  BoxShadow(
                                    color: Colors.white,
                                    offset: Offset(-15, -15),
                                    blurRadius: 30,
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE4EEF3),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.question_mark,
                                            color: Colors.blue[700],
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Le saviez vous ?',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Flexible(
                                      child: Text(
                                        _currentAnecdote,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.blue,
                                        ),
                                        overflow: TextOverflow.fade,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Contenu principal
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Card(
                      elevation: 4,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 24, horizontal: 20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE4EEF3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.water_drop,
                                  color: Colors.blue[700], size: 32),
                            ),
                            const SizedBox(width: 16),
                                    Text.rich(
                                      TextSpan(
                                        text: 'BIENVENUE À : ',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                          color: const Color.fromARGB(255, 18, 16, 101),
                                        ),
                                        children: [
                                          TextSpan(
                                            text: cleanedStationName ?? 'Veuillez sélectionner une station.',
                                            style: selectedStationName == null
                                                ? const TextStyle(fontStyle: FontStyle.italic)
                                                : const TextStyle(),
                                          ),
                                        ],
                                      ),
                                    ),


                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0xFFbebebe),
                                      offset: Offset(15, 15),
                                      blurRadius: 30,
                                    ),
                                    BoxShadow(
                                      color: Colors.white,
                                      offset: Offset(-15, -15),
                                      blurRadius: 30,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: MapScreen(
                                    onStationSelected: (name, data) async {
                                      setState(() {
                                        selectedStationName = name;
                                        selectedStationData = data;
                                        _donneesParametre.clear();
                                      });
                                      await _verifierParametresDisponibles();
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _Card_Graph(),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  flex: 1,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _buildPollutionIQEauCard(),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildPhCardFromData(),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildTemperatureCardFromData(),
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhCardFromData() {
    final phEntry = selectedStationData?['Potentiel Hydrogène (pH)'];

    double? dernierPh;
    if (phEntry != null && phEntry is Map<String, dynamic>) {
      final value = phEntry['resultat'];
      if (value is StationInfo) {
        dernierPh = value.resultat;
      }
    }

    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.science,
                    color: Theme.of(context).colorScheme.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'pH',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 13,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            dernierPh != null
                ? Expanded(
                    // <-- Ajoute ça pour que ça prenne la place restante
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Valeur',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                      fontSize: 9,
                                      fontStyle: FontStyle.normal,
                                    ),
                              ),
                              Text(
                                dernierPh.toStringAsFixed(2),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontSize: 15,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 32,
                          height: 70,
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 227, 227, 227),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: 80 * (dernierPh / 14).clamp(0.0, 1.0),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(context).colorScheme.tertiary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 1.0),
                    child: Text(
                      'Donnée de pH non disponible pour cette station.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                            fontSize: 8,
                          ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _Card_Graph() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFbebebe),
              offset: Offset(15, 15),
              blurRadius: 30,
            ),
            BoxShadow(
              color: Colors.white,
              offset: Offset(-15, -15),
              blurRadius: 30,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Choisir un paramètre :',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                  Container(
                    width: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.transparent),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        canvasColor: Colors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: DropdownButton<String>(
                            hint: const Text(
                              'Sélectionner',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4a90e2),
                                fontSize: 16,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            value: (selectedParametreCode != null &&
                                    parametresDisponibles[
                                            selectedParametreCode] ==
                                        true)
                                ? selectedParametreCode
                                : null,
                            isExpanded: true,
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Color(0xFF4a90e2),
                            ),
                            elevation: 0,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4a90e2),
                              fontSize: 13,
                              fontFamily: 'Poppins',
                            ),
                            items: parametres.entries
                                .where((entry) =>
                                    parametresDisponibles[entry.key] ?? false)
                                .map((entry) {
                              return DropdownMenuItem<String>(
                                value: entry.key,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    entry.value,
                                    style: const TextStyle(
                                      color: Color(0xFF4a90e2),
                                      fontSize: 13,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) async {
                              if (value != null) {
                                setState(() {
                                  selectedParametreCode = value;
                                });
                                await _chargerDonneesParametre();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_donneesParametre.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      selectedParametreCode == null
                          ? 'Veuillez sélectionner un paramètre.'
                          : 'Aucune donnée disponible pour ce paramètre.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: BarChart(
                      BarChartData(
                        backgroundColor: Colors.white,
                        alignment: BarChartAlignment.spaceAround,
                        groupsSpace: 0,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            tooltipBgColor: Colors.blue.withOpacity(0.8),
                            tooltipPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            tooltipMargin: 16,
                            tooltipRoundedRadius: 20,
                            fitInsideVertically: true,
                            fitInsideHorizontally: true,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final date = DateTime.parse(
                                  _donneesParametre[group.x.toInt()]['date']);
                              return BarTooltipItem(
                                '${date.day}/${date.month}/${date.year}',
                                const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500),
                              );
                            },
                          ),
                          touchCallback:
                              (FlTouchEvent event, barTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  barTouchResponse == null ||
                                  barTouchResponse.spot == null) {
                                if (touchedIndex != -1) {
                                  barWidths[touchedIndex] = 8;
                                  _animationController?.forward(from: 0);
                                }
                                touchedIndex = -1;
                                return;
                              }
                              touchedIndex =
                                  barTouchResponse.spot!.touchedBarGroupIndex;
                              barWidths[touchedIndex] = 8;
                            });
                          },
                        ),
                        gridData: const FlGridData(show: false),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 50,
                              getTitlesWidget: (value, meta) {
                                if (value < 0 ||
                                    value >= _donneesParametre.length)
                                  return const SizedBox();
                                final date = DateTime.parse(
                                    _donneesParametre[value.toInt()]['date']);
                                // On ne montre que la première, dernière, et quelques années intermédiaires
                                if (value == 0 ||
                                    value == _donneesParametre.length - 1 ||
                                    value ==
                                        (_donneesParametre.length / 2)
                                            .floor()) {
                                  return Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      '${date.year}',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
// --
                                final maxY = _donneesParametre
                                        .map((e) => double.parse(e['resultat'].toString()))
                                        .reduce((max, v) => v > max ? v : max) * 1.2;

                                // Si la valeur est très proche du maxY, on ne l'affiche pas
                                if ((value - maxY).abs() < 0.01) {
                                  return const SizedBox.shrink();
                                }
// --
                                return Text(
                                  value.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups:
                            List.generate(_donneesParametre.length, (index) {
                          return BarChartGroupData(
                            x: index,
                            barsSpace: 0,
                            barRods: [
                              BarChartRodData(
                                toY: double.parse(_donneesParametre[index]
                                        ['resultat']
                                    .toString()),
                                color: index == touchedIndex
                                    ? Colors.blue.shade300
                                    : Colors.blue,
                                width: barWidths[index] ?? 2,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                  bottom: Radius.circular(0),
                                ),
                              ),
                            ],
                          );
                        }),
                        maxY: _donneesParametre.isEmpty
                            ? 0
                            : _donneesParametre
                                    .map((e) =>
                                        double.parse(e['resultat'].toString()))
                                    .reduce((max, value) =>
                                        value > max ? value : max) *
                                1.2,                                
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemperatureCardFromData() {
    final tempEntry = selectedStationData?['Température de l\'eau'];

    double? dernierTemp;
    if (tempEntry != null && tempEntry is Map<String, dynamic>) {
      final value = tempEntry['resultat'];
      if (value is StationInfo) {
        dernierTemp = value.resultat;
      }
    }

    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize:
              MainAxisSize.max, // important pour remplir l'espace dispo
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.science,
                    color: Theme.of(context).colorScheme.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Température',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 13,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            dernierTemp != null
                ? Expanded(
                    // occupe l'espace restant verticalement
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Valeur',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                      fontSize: 9,
                                    ),
                              ),
                              Text(
                                '${dernierTemp.toStringAsFixed(2)}°C',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontSize: 15,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 32,
                          height: 70, // fixe uniquement la taille de la jauge
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 227, 227, 227),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: 80 *
                                  (dernierTemp / 30).clamp(0.0,
                                      1.0), // ajuste la base max selon tes valeurs
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(context).colorScheme.tertiary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 1.0),
                    child: Text(
                      'Donnée de température non disponible pour cette station.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                            fontSize: 8,
                          ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildPollutionIQEauCard() {
    final data = selectedStationData;

    String niveau = 'Indisponible';
    Color couleur = Colors.grey;
    double? indice;
    double tailleTexte = 13.0; // Valeur par défaut

    if (data != null && data.isNotEmpty) {
      // Récupère les résultats disponibles
      final valeurs = [
        data['Ammonium (NH4)']?['resultat']?.resultat,
        data['Nitrates (NO3)']?['resultat']?.resultat,
        data['Température de l\'eau']?['resultat']?.resultat,
        data['Potentiel Hydrogène (pH)']?['resultat']?.resultat,
        data['Phosphates']?['resultat']?.resultat,
      ].whereType<double>().toList();

      if (valeurs.isNotEmpty) {
        indice = valeurs.reduce((a, b) => a + b) / valeurs.length;

        if (indice < 5) {
          niveau = 'Bonne';
          // couleur = const Color.fromARGB(255, 51, 123, 231);
          // couleur = const Color.fromARGB(255, 139, 195, 74); //v1
          couleur = const Color.fromARGB(255, 100, 180, 150); //v2
          tailleTexte;
        } else if (indice < 10) {


          niveau = 'Moyenne';
          // couleur = const Color.fromARGB(255, 144, 0, 255);
          // couleur = const Color.fromARGB(255, 255, 183, 77); //v1
          couleur = const Color.fromARGB(255, 255, 170, 120); //v2
          tailleTexte;
        } else {
          niveau = 'Mauvaise';
          // couleur = const Color.fromARGB(255, 116, 32, 120);
          // couleur = const Color.fromARGB(255, 244, 67, 54); //v1
          couleur = const Color.fromARGB(255, 200, 90, 90); //v2
          tailleTexte;
        }
      }
    }

    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: couleur.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.water_drop,
                    color: couleur,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Qualité de l\'eau',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: couleur,
                        fontSize: 13,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            indice != null
                ? Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Indice',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                      fontSize: 9,
                                    ),
                              ),
                              Text(
                                indice.toStringAsFixed(2),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: couleur,
                                      fontSize: 15,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          alignment: Alignment
                              .center, // 👈 Centre le contenu dans le container
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: couleur.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            niveau,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: couleur,
                                ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 1.0),
                    child: Text(
                      'Données insuffisantes pour calculer l\'indice.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                            fontSize: 8,
                          ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
