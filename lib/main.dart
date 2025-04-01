import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'api/api_station.dart';


void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final HubEauFlow api = HubEauFlow();
  List<dynamic> _stations = [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    fetchStations();
  }

  void fetchStations() async {
    setState(() => _error = '');
    try {
      final stations = await api.getStations();
      setState(() => _stations = stations.take(5).toList()); // Prend 5 stations max
      if (stations.isEmpty) setState(() => _error = 'Aucune station trouvée.');
    } catch (e) {
      setState(() => _error = 'Erreur lors de la récupération des données.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      home: Scaffold(
        appBar: AppBar(title: const Text('Qualité des Rivières')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (_error.isNotEmpty)
                Text(_error, style: const TextStyle(color: Colors.red)),

              Expanded(
                child: _stations.isNotEmpty
                    ? ListView(
                        children: [
                          SizedBox(height: 10),
                          Text("Nombre de stations",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 150, child: BarChartWidget(stations: _stations)),

                          SizedBox(height: 20),
                          Text("Evolution d'une mesure",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 150, child: LineChartWidget(stations: _stations)),

                          SizedBox(height: 20),
                          Text("Répartition des stations",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 150, child: PieChartWidget(stations: _stations)),
                        ],
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Graphique en Barres avec Nom des Stations
class BarChartWidget extends StatelessWidget {
  final List<dynamic> stations;
  BarChartWidget({required this.stations});

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        barGroups: stations.asMap().entries.map((entry) {
          int index = entry.key;
          var station = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: station['libelle_station'].length.toDouble(),
                color: Colors.blueAccent,
                width: 10,
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                return index < stations.length
                    ? RotatedBox(
                        quarterTurns: 1,
                        child: Text(stations[index]['libelle_station'].substring(0, 3),
                            style: TextStyle(fontSize: 10)),
                      )
                    : Container();
              },
            ),
          ),
        ),
      ),
    );
  }
}

// Graphique en Courbes avec Valeurs Réelles
class LineChartWidget extends StatelessWidget {
  final List<dynamic> stations;
  LineChartWidget({required this.stations});

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: stations.asMap().entries.map((entry) {
              int index = entry.key;
              var station = entry.value;
              return FlSpot(index.toDouble(), station['libelle_station'].length.toDouble());
            }).toList(),
            isCurved: true,
            color: Colors.greenAccent,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.3)),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                return index < stations.length
                    ? Text(stations[index]['libelle_station'].substring(0, 3), style: TextStyle(fontSize: 10))
                    : Container();
              },
            ),
          ),
        ),
      ),
    );
  }
}

// Graphique en Camembert avec Répartition des Stations
class PieChartWidget extends StatelessWidget {
  final List<dynamic> stations;
  PieChartWidget({required this.stations});

  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        sections: stations.asMap().entries.map((entry) {
          int index = entry.key;
          var station = entry.value;
          return PieChartSectionData(
            value: station['libelle_station'].length.toDouble(),
            title: station['libelle_station'].substring(0, 3),
            color: Colors.primaries[index % Colors.primaries.length],
            radius: 40,
          );
        }).toList(),
      ),
    );
  }
}