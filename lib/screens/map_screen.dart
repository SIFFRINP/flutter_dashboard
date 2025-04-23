import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geojson_vi/geojson_vi.dart';
import '../services/api_service.dart';

class MapScreen extends StatefulWidget {
  final Function(String, Map<String, dynamic>)? onStationSelected;

  const MapScreen({Key? key, this.onStationSelected}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

// Classe pour lier un polygone à son nom
class RegionPolygon {
  final Polygon polygon;
  final String name;
  final String codeRegion;

  RegionPolygon(
      {required this.polygon, required this.name, required this.codeRegion});
}

class _MapScreenState extends State<MapScreen> {
  List<RegionPolygon> regionPolygons = [];
  List<Marker> stationMarkers = [];
  late MapController _mapController;

  final Map<String, String> regionCodes = {
    "Île-de-France": "11",
    "Hauts-de-France": "32",
    "Normandie": "28",
    "Bretagne": "53",
    "Pays de la Loire": "52",
    "Centre-Val de Loire": "24",
    "Grand Est": "44",
    "Provence-Alpes-Côte d'Azur": "93",
    "Auvergne-Rhône-Alpes": "84",
    "Nouvelle-Aquitaine": "75",
    "Occitanie": "76",
    "Bourgogne-Franche-Comté": "27",
    "Corse": "94"
  };

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    loadGeoJson().then((_) {
      // Charger les stations pour toute la France (code région 0)
      loadStationsForRegion("0");
    });
  }

  Future<void> loadStationsForRegion(String regionCode) async {
    try {
      final stations = await ApiService.fetchStations(regionCode);
      if (stations.isEmpty) {
        print("Aucune station trouvée pour la région $regionCode");
      }

      List<Marker> markers = stations.map((station) {
        return Marker(
          width: 5.0,
          height: 5.0,
          point: LatLng(station.latitude, station.longitude),
          child: GestureDetector(
            onTap: () async {
              Map<String, dynamic> fullData = {};

              try {
                // 🔹 Donnée pH
                final phData = await ApiService.fetchStationPH(station.code);
                if (phData != null && phData.isNotEmpty) {
                  fullData['Potentiel Hydrogène (pH)'] = phData;
                }

                // 🔹 Donnée température
                final tempData =
                    await ApiService.fetchStationTemp(station.code);
                if (tempData != null && tempData.isNotEmpty) {
                  fullData['Température de l\'eau'] = tempData;
                }

                // 🔹 Récupération de tous les paramètres en une seule requête
                final allParametersData =
                    await ApiService.fetchStationPollution(station.code);
                if (allParametersData?.isNotEmpty ?? false) {
                  allParametersData?.forEach((param, value) {
                    if (value != null) {
                      fullData[param] = value;
                    }
                  });
                }

                // On ajoute le code de la station dans les données
                fullData['code_station'] = station.code;
              } catch (e) {
                print(
                    "Erreur lors du chargement des données pour ${station.nom} : $e");
              }

              if (widget.onStationSelected != null) {
                widget.onStationSelected!(station.nom, fullData);
              }
            },
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    const Color.fromARGB(255, 105, 165, 255), // Point central
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(255, 190, 216, 255)
                        .withOpacity(0.4), // Halo
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList();

      setState(() {
        stationMarkers = markers;
      });
    } catch (e) {
      print("Erreur lors du chargement des stations : $e");
    }
  }

  // Fonction pour charger le GeoJSON des régions
  Future<void> loadGeoJson() async {
    final String data =
        await rootBundle.loadString('assets/france_regions.geojson');
    final featureCollection = GeoJSONFeatureCollection.fromJSON(data);

    List<RegionPolygon> tempPolygons = [];

    for (var feature in featureCollection.features) {
      final geometry = feature?.geometry;
      final regionName = feature?.properties?['nom'] ?? 'Région inconnue';
      final regionCode = feature?.properties?['code'] ?? '00';

      if (geometry is GeoJSONPolygon) {
        final coordinates = geometry.coordinates;
        for (var ring in coordinates) {
          final points =
              ring.map((coord) => LatLng(coord[1], coord[0])).toList();

          final polygon = Polygon(
            points: points,
            color: Colors.transparent,
            borderColor: Colors.transparent,
            borderStrokeWidth: 1.0,
          );

          tempPolygons.add(RegionPolygon(
              polygon: polygon, name: regionName, codeRegion: regionCode));
        }
      } else if (geometry is GeoJSONMultiPolygon) {
        for (var multiPolygon in geometry.coordinates) {
          for (var polygonCoords in multiPolygon) {
            final points = polygonCoords
                .map((coord) => LatLng(coord[1], coord[0]))
                .toList();

            final polygon = Polygon(
              points: points,
              color: Colors
                  .transparent, // ou Colors.black.withOpacity(0.1) par ex.
              borderColor: Colors.transparent,
              borderStrokeWidth: 1.0,
            );

            tempPolygons.add(RegionPolygon(
                polygon: polygon, name: regionName, codeRegion: regionCode));
          }
        }
      }
    }

    setState(() {
      regionPolygons = tempPolygons;
    });
  }

  // Fonction pour détecter si un point est à l'intérieur d'un polygone
  bool isPointInPolygon(LatLng point, List<LatLng> polygonPoints) {
    int intersections = 0;
    for (int i = 0; i < polygonPoints.length; i++) {
      int j = (i + 1) % polygonPoints.length;
      LatLng p1 = polygonPoints[i];
      LatLng p2 = polygonPoints[j];

      if (point.latitude > p1.latitude && point.latitude <= p2.latitude ||
          point.latitude > p2.latitude && point.latitude <= p1.latitude) {
        if (point.longitude <=
            (p2.longitude - p1.longitude) *
                    (point.latitude - p1.latitude) /
                    (p2.latitude - p1.latitude) +
                p1.longitude) {
          intersections++;
        }
      }
    }
    return intersections % 2 != 0;
  }

  // Fonction pour obtenir la bounding box d'un polygone
  LatLngBounds getBoundingBox(List<LatLng> points) {
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLon = points[0].longitude;
    double maxLon = points[0].longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    return LatLngBounds(
      LatLng(minLat, minLon),
      LatLng(maxLat, maxLon),
    );
  }

  // Fonction appelée lorsque l'utilisateur touche la carte
  void _onTapMap(LatLng latlng) {
    for (var region in regionPolygons) {
      if (isPointInPolygon(latlng, region.polygon.points)) {
        print('Région sélectionnée : ${region.name}');
        LatLngBounds bounds = getBoundingBox(region.polygon.points);

        final padding = 20.0;

        final northEast = LatLng(bounds.north + padding, bounds.east + padding);
        final southWest = LatLng(bounds.south - padding, bounds.west - padding);

        final center = LatLng(
          (northEast.latitude + southWest.latitude) / 2,
          (northEast.longitude + southWest.longitude) / 2,
        );

        _mapController.move(center, 8.0);

        // On passe le code de la région au lieu du nom
        loadStationsForRegion(region.codeRegion);

        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: Text('Carte des Régions')),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: const LatLng(46.603354, 1.888334),
          initialZoom: 5.5,
          minZoom: 4.0,
          maxZoom: 10.0,
          onTap: (tapPosition, latlng) {
            _onTapMap(latlng);
          },
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://api.mapbox.com/styles/v1/nopernin/cm9okvjh9004u01s057ms1ifo/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1Ijoibm9wZXJuaW4iLCJhIjoiY205bzdmOGRqMHB0cDJpc2FxNTdqa2trayJ9.ihHZhoE1ojbmHgRxMScfpg',
            additionalOptions: {
              'accessToken':
                  'pk.eyJ1Ijoibm9wZXJuaW4iLCJhIjoiY205bzdmOGRqMHB0cDJpc2FxNTdqa2trayJ9.ihHZhoE1ojbmHgRxMScfpg',
            },
          ),
          PolygonLayer(
            polygons: regionPolygons.map((e) => e.polygon).toList(),
          ),
          MarkerLayer(markers: stationMarkers),
        ],
      ),
    );
  }
}
