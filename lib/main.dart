import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
// import 'package:fl_chart/fl_chart.dart';

class HubEauFlow {
  final String rootPath = 'https://hubeau.eaufrance.fr/api/v2/qualite_rivieres';
  final Dio dio = Dio();

  Future<List<dynamic>> getStations({
    String format = 'json',
    String? codeStation,
    String? libelleStation,
  }) async {
    try {
      final response = await dio.get(
        '$rootPath/stations',
        queryParameters: {
          'format': format,
          if (codeStation != null) 'code_station': codeStation,
          if (libelleStation != null) 'libelle_station': libelleStation,
        },
      );
      return response.data['data'];
    } catch (e) {
      print('Erreur : $e');
      return [];
    }
  }
}

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final HubEauFlow api = HubEauFlow();
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _stations = [];
  String _error = '';

  void fetchStations() async {
    setState(() => _error = '');
    try {
      final stations = await api.getStations(libelleStation: _controller.text);
      setState(() => _stations = stations);
      if (stations.isEmpty) setState(() => _error = 'Aucune station trouvée.');
    } catch (e) {
      setState(() => _error = 'Erreur lors de la récupération des données.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Recherche de station HubEau')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Entrez le nom de la station',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: fetchStations,
                child: const Text('Rechercher'),
              ),
              const SizedBox(height: 20),
              if (_error.isNotEmpty) Text(_error, style: const TextStyle(color: Colors.red)),
              Expanded(
                child: ListView.builder(
                  itemCount: _stations.length,
                  itemBuilder: (context, index) {
                    final station = _stations[index];
                    return ListTile(
                      title: Text(station['libelle_station'] ?? 'Nom inconnu'),
                      subtitle: Text('Code: ${station['code_station'] ?? 'Inconnu'}'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}