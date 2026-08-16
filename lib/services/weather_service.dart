import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

class WeatherRisk {
  final String label;
  final String summary;
  final double? precipitationMm;
  final double? temperatureC;
  final DateTime fetchedAt;

  const WeatherRisk({
    required this.label,
    required this.summary,
    this.precipitationMm,
    this.temperatureC,
    required this.fetchedAt,
  });

  factory WeatherRisk.fromJson(Map<String, dynamic> json) {
    final level = (json['risk_label'] ?? json['level'] ?? 'Unavailable')
        .toString();
    final rain = (json['precipitation_mm'] ?? json['total_rain_mm'] as num?)
        ?.toDouble();
    final warmDays = json['warm_days'];
    final fallbackSummary = level == 'Unavailable'
        ? 'Weather information is currently unavailable. This is not a dengue prediction.'
        : 'The seven-day forecast includes ${rain?.toStringAsFixed(1) ?? 'unknown'} mm rain'
              '${warmDays == null ? '' : ' and $warmDays warm day(s)'}. This app-defined indicator describes possible mosquito-breeding conditions only—not dengue cases or a clinical risk.';
    return WeatherRisk(
      label: level,
      summary: (json['summary'] ?? fallbackSummary).toString(),
      precipitationMm: rain,
      temperatureC: (json['temperature_c'] as num?)?.toDouble(),
      fetchedAt: DateTime.tryParse('${json['fetched_at']}') ?? DateTime.now(),
    );
  }
}

/// Reads a server-computed mosquito breeding-condition indicator.
/// It is explicitly not a dengue diagnosis, forecast, or case prediction.
class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  Future<WeatherRisk> fetchRisk({
    required double latitude,
    required double longitude,
  }) async {
    if (!SupabaseConfig.isConfigured ||
        Supabase.instance.client.auth.currentSession == null) {
      return WeatherRisk(
        label: 'Unavailable',
        summary:
            'Configure Supabase and sign in to load the weather-based breeding-condition indicator.',
        fetchedAt: DateTime.now(),
      );
    }
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'weather-risk',
        body: {'latitude': latitude, 'longitude': longitude},
      );
      if (response.data is Map) {
        return WeatherRisk.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
    } catch (_) {
      // Return a truthful unavailable state; do not invent weather values.
    }
    return WeatherRisk(
      label: 'Unavailable',
      summary:
          'Live weather data could not be loaded. This indicator describes breeding conditions only—not dengue risk or a diagnosis.',
      fetchedAt: DateTime.now(),
    );
  }
}
