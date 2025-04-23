import 'dart:convert';
import 'package:http/http.dart' as http;

/// Représente une station de mesure
class Station {
  final String nom;
  final double longitude;
  final double latitude;
  final String code;

  Station({
    required this.nom,
    required this.longitude,
    required this.latitude,
    required this.code,
  });
}

/// Représente une mesure de paramètre
class StationInfo {
  final String parametre;
  final double resultat;
  final String datePrelevement;

  StationInfo({
    required this.parametre,
    required this.resultat,
    required this.datePrelevement,
  });
}

class ApiService {
  /// Récupère les stations selon une région
  static Future<List<Station>> fetchStations(String codeRegion) async {
    final url = Uri.parse(
      'https://hubeau.eaufrance.fr/api/v2/qualite_rivieres/station_pc'
      '?code_region=$codeRegion&code_parametre=1301,1302&size=2000',
    );

    final response = await http.get(url);

    if (response.statusCode == 200 || response.statusCode == 206) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      List stations = data['data'];

      return stations.map<Station>((station) {
        return Station(
          nom: station['libelle_station'] ?? 'Nom inconnu',
          longitude:
              double.tryParse(station['longitude']?.toString() ?? '') ?? 0.0,
          latitude:
              double.tryParse(station['latitude']?.toString() ?? '') ?? 0.0,
          code: station['code_station'] ?? '',
        );
      }).toList();
    } else {
      print('Erreur API: ${response.statusCode} - ${response.body}');
      throw Exception('Erreur: Impossible de récupérer les stations');
    }
  }

  /// Récupère la dernière mesure de pH pour une station
  static Future<Map<String, dynamic>?> fetchStationPH(
      String codeStation) async {
    final url = Uri.parse(
      'https://hubeau.eaufrance.fr/api/v2/qualite_rivieres/analyse_pc'
      '?code_station=$codeStation&code_parametre=1302&size=2000',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      List results = data['data'];

      if (results.isEmpty) return null;

      results.sort((a, b) {
        DateTime dateA = DateTime.parse(a['date_prelevement']);
        DateTime dateB = DateTime.parse(b['date_prelevement']);
        return dateB.compareTo(dateA); // Trie décroissant
      });

      final latestResult = results.first;
      final pHValue =
          double.tryParse(latestResult['resultat']?.toString() ?? '') ?? 0.0;

      // Vérification des valeurs aberrantes
      if (pHValue < 0.0 || pHValue > 14.0) {
        print("Valeur aberrante détectée pour le pH : $pHValue");
        return null; // Ignorez cette valeur
      }

      return {
        'resultat': StationInfo(
          parametre: latestResult['libelle_parametre'] ?? 'Inconnu',
          resultat:
              double.tryParse(latestResult['resultat']?.toString() ?? '') ??
                  0.0,
          datePrelevement: latestResult['date_prelevement'] ?? '',
        ),
        // 'date': latestResult['date_prelevement'],
      };
    } else {
      print('Erreur API: ${response.statusCode} - ${response.body}');
      throw Exception('Erreur: Impossible de récupérer les résultats de pH');
    }
  }

  /// Récupère la dernière mesure de température pour une station
  static Future<Map<String, dynamic>?> fetchStationTemp(
      String codeStation) async {
    final url = Uri.parse(
      'https://hubeau.eaufrance.fr/api/v2/qualite_rivieres/analyse_pc'
      '?code_station=$codeStation&code_parametre=1301&size=2000',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      List results = data['data'];

      if (results.isEmpty) return null;

      // Trier les résultats par la date la plus récente (en partant du principe que la date est dans 'date_mesure')
      results.sort((a, b) {
        DateTime dateA = DateTime.parse(a['date_prelevement']);
        DateTime dateB = DateTime.parse(b['date_prelevement']);
        return dateB.compareTo(dateA); // Trier par date décroissante
      });

      final latestResult = results[0]; // Le plus récent

      return {
        'resultat': StationInfo(
          parametre: latestResult['libelle_parametre'] ?? 'Inconnu',
          resultat:
              double.tryParse(latestResult['resultat']?.toString() ?? '') ??
                  0.0,
          datePrelevement: latestResult['date_prelevement'] ?? '',
        ),
        // 'date': latestResult['date_prelevement'],
      };
    } else {
      print('Erreur API: ${response.statusCode} - ${response.body}');
      throw Exception('Erreur: Impossible de récupérer les résultats');
    }
  }

  /// Récupère la dernière mesure des paramètres pour l'indice de pollution pour une station
  static Future<Map<String, dynamic>?> fetchStationPollution(
      String codeStation) async {
    List<int> parametresCodes = [
      1301,
      1302,
      1303,
      1304,
      1305,
      1306,
      1307,
      1309
    ];

    Map<String, dynamic> pollutionData = {};

    // Parcourir chaque code de paramètre et effectuer un appel API pour récupérer les données
    for (int code in parametresCodes) {
      final url = Uri.parse(
        'https://hubeau.eaufrance.fr/api/v2/qualite_rivieres/analyse_pc'
        '?code_station=$codeStation&code_parametre=$code&size=2000',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        List results = data['data'];

        if (results.isEmpty) {
          // Si aucune donnée n'est trouvée, on passe au paramètre suivant
          pollutionData['parametre_$code'] = null;
          continue;
        }

        // Trier les résultats par la date la plus récente
        results.sort((a, b) {
          DateTime dateA = DateTime.parse(a['date_prelevement']);
          DateTime dateB = DateTime.parse(b['date_prelevement']);
          return dateB.compareTo(dateA); // Trier par date décroissante
        });

        final latestResult = results[0]; // Le plus récent

        pollutionData['parametre_$code'] = StationInfo(
          parametre: latestResult['libelle_parametre'] ?? 'Inconnu',
          resultat:
              double.tryParse(latestResult['resultat']?.toString() ?? '') ??
                  0.0,
          datePrelevement: latestResult['date_prelevement'] ?? '',
        );
      } else {
        print('Erreur API: ${response.statusCode} - ${response.body}');
        throw Exception('Erreur: Impossible de récupérer les résultats');
      }
    }

    return pollutionData;
  }

  /// Récupère les mesures du paramètre choisi par l'utilisateur pour une station
  static Future<List<Map<String, dynamic>>?> fetchStationParaDuree(
      String codeStation, String codeParametre) async {
    final url = Uri.parse(
      'https://hubeau.eaufrance.fr/api/v2/qualite_rivieres/analyse_pc'
      '?code_station=$codeStation&code_parametre=$codeParametre&size=2000',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      List results = data['data'];

      if (results.isEmpty) return null;

      // Trier les résultats par date de prélèvement (la plus récente en premier)
      results.sort((a, b) {
        DateTime dateA = DateTime.parse(a['date_prelevement']);
        DateTime dateB = DateTime.parse(b['date_prelevement']);
        return dateB.compareTo(dateA); // Trier par date décroissante
      });

      // Construire une liste des résultats
      List<Map<String, dynamic>> allResults = results.map((result) {
        return {
          'resultat':
              double.tryParse(result['resultat']?.toString() ?? '') ?? 0.0,
          'date': result['date_prelevement'],
          'parametre': result['libelle_parametre'] ?? 'Inconnu',
        };
      }).toList();

      return allResults;
    } else {
      print('Erreur API: ${response.statusCode} - ${response.body}');
      throw Exception('Erreur: Impossible de récupérer les résultats');
    }
  }
}
