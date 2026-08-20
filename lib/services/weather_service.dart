// lib/services/weather_service.dart
//
// Reads a 7-day forecast from Open-Meteo (https://open-meteo.com) — a free,
// keyless, public weather API — and turns it into an app-defined mosquito
// breeding-condition indicator. This used to be proxied through a Supabase
// Edge Function (supabase/functions/weather-risk), which is why the card
// always showed "Unavailable": the function was never deployed. Open-Meteo
// needs no API key or secret to protect, so the edge-function hop bought
// nothing but an extra point of failure — called directly here instead,
// the same way dengue_api_service.dart and geocoding_service.dart already
// call their own free public APIs.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

class WeatherRisk {
  final String label;
  final String summary;
  final double? precipitationMm;
  final double? temperatureC;
  final List<double> dailyRainMm;
  final DateTime fetchedAt;

  const WeatherRisk({
    required this.label,
    required this.summary,
    this.precipitationMm,
    this.temperatureC,
    this.dailyRainMm = const [],
    required this.fetchedAt,
  });

  static WeatherRisk unavailable(String summary) => WeatherRisk(
    label: 'Unavailable',
    summary: summary,
    fetchedAt: DateTime.now(),
  );
}

/// Reads a client-computed mosquito breeding-condition indicator from a
/// live weather forecast. It is explicitly not a dengue diagnosis, forecast,
/// or case prediction.
class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  static const _forecastUrl = 'https://api.open-meteo.com/v1/forecast';

  Future<WeatherRisk> fetchRisk({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(_forecastUrl).replace(
      queryParameters: {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'daily': 'precipitation_sum,temperature_2m_max,temperature_2m_min',
        'timezone': 'Asia/Manila',
        'forecast_days': '7',
      },
    );

    try {
      final response = await http
          .get(uri, headers: {'User-Agent': 'BantayDengue/1.0 community-health-demo'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        return WeatherRisk.unavailable(
          'Weather service returned an error (code ${response.statusCode}).',
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final daily = body['daily'] as Map<String, dynamic>?;
      final rainfall = ((daily?['precipitation_sum'] as List?) ?? [])
          .map((v) => (v as num?)?.toDouble() ?? 0.0)
          .toList();
      final maxTemps = ((daily?['temperature_2m_max'] as List?) ?? [])
          .map((v) => (v as num?)?.toDouble() ?? 0.0)
          .toList();
      if (rainfall.isEmpty || maxTemps.isEmpty) {
        return WeatherRisk.unavailable(
          'The weather service returned an unexpected response.',
        );
      }

      final totalRainMm = rainfall.fold<double>(0, (sum, v) => sum + v);
      final warmDays = maxTemps.where((t) => t >= 27).length;
      // Same app-defined scoring the old edge function used: rain volume and
      // consecutive warm days both extend standing-water mosquito breeding.
      final score = math.min(100, (totalRainMm * 1.5 + warmDays * 5).round());
      final level = score >= 70 ? 'high' : (score >= 35 ? 'moderate' : 'low');

      return WeatherRisk(
        label: level,
        summary:
            'The seven-day forecast includes ${totalRainMm.toStringAsFixed(1)} mm rain '
            'and $warmDays warm day(s). This app-defined indicator describes possible '
            'mosquito-breeding conditions only—not dengue cases or a clinical risk.',
        precipitationMm: totalRainMm,
        temperatureC: maxTemps.first,
        dailyRainMm: rainfall,
        fetchedAt: DateTime.now(),
      );
    } on SocketException {
      return WeatherRisk.unavailable(
        'No internet connection. Please check your network and try again.',
      );
    } catch (_) {
      return WeatherRisk.unavailable(
        'Live weather data could not be loaded. This indicator describes '
        'breeding conditions only—not dengue risk or a diagnosis.',
      );
    }
  }
}
