import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Worldwide Weather',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const WeatherHome(),
    );
  }
}

class WeatherHome extends StatefulWidget {
  const WeatherHome({super.key});

  @override
  State<WeatherHome> createState() => _WeatherHomeState();
}

class _WeatherHomeState extends State<WeatherHome> {
  final TextEditingController searchController = TextEditingController();

  bool loading = false;
  String cityName = 'Dhaka';
  String countryName = '';
  String weatherText = 'Loading...';

  double? temperature;
  double? windSpeed;
  int? humidity;

  double? latitude;
  double? longitude;

  @override
  void initState() {
    super.initState();
    _loadWeather(23.8103, 90.4125, 'Dhaka', 'Bangladesh');
  }

  // ------------------------------------------------------------
  // WEATHER CODE
  // ------------------------------------------------------------

  String weatherDescription(int code) {
    if (code == 0) return 'Clear sky';
    if (code == 1 || code == 2) return 'Partly cloudy';
    if (code == 3) return 'Overcast';
    if (code == 45 || code == 48) return 'Fog';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code >= 61 && code <= 67) return 'Rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Rain showers';
    if (code >= 85 && code <= 86) return 'Snow showers';
    if (code == 95) return 'Thunderstorm';
    if (code == 96 || code == 99) return 'Thunderstorm with hail';

    return 'Unknown weather';
  }

  IconData weatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny;
    if (code == 1 || code == 2 || code == 3) {
      return Icons.cloud;
    }
    if (code == 45 || code == 48) return Icons.foggy;
    if (code >= 51 && code <= 67) return Icons.grain;
    if (code >= 71 && code <= 86) return Icons.ac_unit;
    if (code >= 95) return Icons.thunderstorm;

    return Icons.cloud;
  }

  // ------------------------------------------------------------
  // GET WEATHER
  // ------------------------------------------------------------

  Future<void> _loadWeather(
      double lat,
      double lon,
      String name,
      String country,
      ) async {
    setState(() {
      loading = true;
      cityName = name;
      countryName = country;
      latitude = lat;
      longitude = lon;
    });

    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
            '?latitude=$lat'
            '&longitude=$lon'
            '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m'
            '&timezone=auto',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception('Weather request failed');
      }

      final data = jsonDecode(response.body);
      final current = data['current'];

      final int code = current['weather_code'];

      setState(() {
        temperature = (current['temperature_2m'] as num).toDouble();
        humidity = (current['relative_humidity_2m'] as num).toInt();
        windSpeed = (current['wind_speed_10m'] as num).toDouble();

        weatherText = weatherDescription(code);
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        weatherText = 'Could not load weather';
      });

      _showMessage('Could not load weather. Check internet connection.');
    }
  }

  // ------------------------------------------------------------
  // WORLDWIDE CITY SEARCH
  // ------------------------------------------------------------

  Future<void> searchCity() async {
    final query = searchController.text.trim();

    if (query.isEmpty) {
      _showMessage('Enter a city name');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final url = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search'
            '?name=${Uri.encodeQueryComponent(query)}'
            '&count=10'
            '&language=en'
            '&format=json',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception('Search failed');
      }

      final data = jsonDecode(response.body);

      if (data['results'] == null || data['results'].isEmpty) {
        setState(() {
          loading = false;
        });

        _showMessage('City not found');
        return;
      }

      final result = data['results'][0];

      final double lat = (result['latitude'] as num).toDouble();
      final double lon = (result['longitude'] as num).toDouble();

      final String name = result['name'] ?? query;
      final String country = result['country'] ?? '';

      FocusScope.of(context).unfocus();

      await _loadWeather(lat, lon, name, country);
    } catch (e) {
      setState(() {
        loading = false;
      });

      _showMessage('Could not search city. Check internet connection.');
    }
  }

  // ------------------------------------------------------------
  // CURRENT PHONE LOCATION
  // ------------------------------------------------------------

  Future<void> getCurrentLocation() async {
    setState(() {
      loading = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        setState(() {
          loading = false;
        });

        _showMessage('Please turn ON Location/GPS on your phone.');
        return;
      }

      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          loading = false;
        });

        _showMessage('Location permission denied.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          loading = false;
        });

        _showMessage(
          'Location permission permanently denied. '
              'Enable it from phone Settings.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final lat = position.latitude;
      final lon = position.longitude;

      // Reverse geocoding using Open-Meteo
      final reverseUrl = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/reverse'
            '?latitude=$lat'
            '&longitude=$lon'
            '&language=en'
            '&format=json',
      );

      String name = 'Current Location';
      String country = '';

      try {
        final reverseResponse = await http.get(reverseUrl);

        if (reverseResponse.statusCode == 200) {
          final reverseData = jsonDecode(reverseResponse.body);

          if (reverseData['results'] != null &&
              reverseData['results'].isNotEmpty) {
            final result = reverseData['results'][0];

            name = result['name'] ?? 'Current Location';
            country = result['country'] ?? '';
          }
        }
      } catch (_) {
        // Weather can still load even if city name lookup fails.
      }

      await _loadWeather(lat, lon, name, country);
    } catch (e) {
      setState(() {
        loading = false;
      });

      _showMessage('Unable to get your current location.');
    }
  }

  // ------------------------------------------------------------
  // MESSAGE
  // ------------------------------------------------------------

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Worldwide Weather',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (latitude != null && longitude != null) {
              await _loadWeather(
                latitude!,
                longitude!,
                cityName,
                countryName,
              );
            }
          },

          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // SEARCH BOX
              TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => searchCity(),
                decoration: InputDecoration(
                  hintText: 'Search any city in the world',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: searchCity,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // CURRENT LOCATION BUTTON
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: loading ? null : getCurrentLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text(
                    'Use My Current Location',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              if (loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Column(
                  children: [
                    // CITY
                    Text(
                      cityName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    if (countryName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          countryName,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white70,
                          ),
                        ),
                      ),

                    const SizedBox(height: 30),

                    // WEATHER CARD
                    Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF263238),
                            Color(0xFF102027),
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            weatherIcon(
                              _getWeatherCodeFromText(weatherText),
                            ),
                            size: 80,
                          ),

                          const SizedBox(height: 15),

                          Text(
                            temperature == null
                                ? '--°C'
                                : '${temperature!.toStringAsFixed(1)}°C',
                            style: const TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 10),

                          Text(
                            weatherText,
                            style: const TextStyle(
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // INFO CARDS
                    Row(
                      children: [
                        Expanded(
                          child: _infoCard(
                            Icons.water_drop,
                            'Humidity',
                            humidity == null
                                ? '--'
                                : '$humidity%',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _infoCard(
                            Icons.air,
                            'Wind',
                            windSpeed == null
                                ? '--'
                                : '${windSpeed!.toStringAsFixed(1)} km/h',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    if (latitude != null && longitude != null)
                      Text(
                        'Coordinates: '
                            '${latitude!.toStringAsFixed(4)}, '
                            '${longitude!.toStringAsFixed(4)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white54,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(
      IconData icon,
      String title,
      String value,
      ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  int _getWeatherCodeFromText(String text) {
    if (text == 'Clear sky') return 0;
    if (text == 'Partly cloudy') return 2;
    if (text == 'Overcast') return 3;
    if (text == 'Fog') return 45;
    if (text == 'Drizzle') return 51;
    if (text == 'Rain') return 61;
    if (text == 'Snow') return 71;
    if (text == 'Rain showers') return 80;
    if (text == 'Snow showers') return 85;
    if (text == 'Thunderstorm') return 95;

    return 3;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}