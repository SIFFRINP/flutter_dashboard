import 'package:dio/dio.dart';

class HubEauFlow {
  final String rootPath = 'https://hubeau.eaufrance.fr/api/v2/qualite_rivieres';
  final Dio dio = Dio();

  Future<List<dynamic>> getStations({String format = 'json'}) async {
    try {
      final response = await dio.get('$rootPath/station_pc', queryParameters: {
        'format': format,
      });
      return response.data['data'];
    } catch (e) {
      print('Erreur : $e');
      return [];
    }
  }
}