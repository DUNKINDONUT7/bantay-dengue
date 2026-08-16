// lib/services/dengue_api_service.dart
// Fetches real, official dengue data from two independent WHO public
// endpoints (xMart OData API):
//
//  1. ARBOV / V_DENGUE_GLOBAL_VALIDATED_PUBLIC — weekly surveillance
//     counts (cases, severe cases, deaths) from WHO's Global Dengue
//     Dashboard (https://worldhealthorg.shinyapps.io/dengue_global/).
//  2. DEX_CMS / GHE_FULL_DD — WHO Global Health Estimates, filtered to
//     the "Dengue" cause, giving the long-term annual death rate per
//     100,000 population for a country.
//
// Both endpoints are queried with a country filter the user can change in
// the UI, so this service also powers the app's search/filter feature —
// switching country re-runs both GET requests with a new $filter.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/dengue_stat_model.dart';

class DengueApiException implements Exception {
  final String message;
  const DengueApiException(this.message);

  @override
  String toString() => message;
}

class DengueApiService {
  static const _surveillanceUrl =
      'https://xmart-api-public.who.int/ARBOV/V_DENGUE_GLOBAL_VALIDATED_PUBLIC';
  static const _mortalityUrl =
      'https://xmart-api-public.who.int/DEX_CMS/GHE_FULL_DD';

  static Future<http.Response> _get(Uri uri) async {
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw DengueApiException(
          'WHO data service returned an error (code ${response.statusCode}).',
        );
      }
      return response;
    } on SocketException {
      throw const DengueApiException(
        'No internet connection. Please check your network and try again.',
      );
    } on HttpException {
      throw const DengueApiException('Unable to reach the WHO data service.');
    } on DengueApiException {
      rethrow;
    } catch (_) {
      throw const DengueApiException(
        'Something went wrong while fetching dengue data.',
      );
    }
  }

  /// Endpoint 1 — weekly surveillance counts for a given country
  /// (default: Philippines, ISO3 = PHL), most recent first.
  static Future<List<DengueStat>> fetchRecentStats({
    String iso3 = 'PHL',
    int weeks = 12,
  }) async {
    final uri = Uri.parse(_surveillanceUrl).replace(
      queryParameters: {
        r'$filter': "ISO3 eq '$iso3'",
        r'$orderby': 'START_DATE desc',
        r'$top': '$weeks',
        'excludeSysColumns': '0',
      },
    );

    final response = await _get(uri);

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final list = body['value'] as List<dynamic>;
      return list
          .map((item) => DengueStat.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw const DengueApiException(
        'Received an invalid response from the WHO data service.',
      );
    }
  }

  /// Endpoint 2 — annual dengue death rate (per 100,000 population) for a
  /// given country, most recent years first. A separate WHO data product
  /// (Global Health Estimates) from a different xMart table than
  /// [fetchRecentStats], demonstrating a second, independent API endpoint.
  static Future<List<DengueMortalityPoint>> fetchMortalityTrend({
    String iso3 = 'PHL',
    int years = 6,
  }) async {
    final uri = Uri.parse(_mortalityUrl).replace(
      queryParameters: {
        r'$filter':
            "DIM_GHECAUSE_TITLE eq 'Dengue' and DIM_COUNTRY_CODE eq '$iso3' and DIM_SEX_CODE eq 'BTSX'",
        r'$orderby': 'DIM_YEAR_CODE desc',
        r'$top': '$years',
      },
    );

    final response = await _get(uri);

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final list = body['value'] as List<dynamic>;
      return list
          .map(
            (item) =>
                DengueMortalityPoint.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      throw const DengueApiException(
        'Received an invalid response from the WHO data service.',
      );
    }
  }
}
