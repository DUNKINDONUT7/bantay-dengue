// lib/models/dengue_stat_model.dart
// Model for a single record returned by the WHO Global Dengue Surveillance
// API (V_DENGUE_GLOBAL_VALIDATED_PUBLIC). Each record is one country's
// case count for one epidemiological week.
// Docs / dashboard: https://worldhealthorg.shinyapps.io/dengue_global/

class DengueStat {
  final String country;
  final String iso3;
  final String whoRegion;
  final int year;
  final DateTime startDate;
  final int? cases;
  final int? confirmedCases;
  final int? severeCases;
  final int? deaths;
  final int? population;

  DengueStat({
    required this.country,
    required this.iso3,
    required this.whoRegion,
    required this.year,
    required this.startDate,
    required this.cases,
    required this.confirmedCases,
    required this.severeCases,
    required this.deaths,
    required this.population,
  });

  factory DengueStat.fromJson(Map<String, dynamic> json) {
    return DengueStat(
      country: json['COUNTRY'] as String? ?? 'Unknown',
      iso3: json['ISO3'] as String? ?? '',
      whoRegion: json['WHO_REGION'] as String? ?? '',
      year: (json['YEAR'] as num?)?.toInt() ?? 0,
      startDate:
          DateTime.tryParse(json['START_DATE'] as String? ?? '') ??
          DateTime.now(),
      cases: (json['CASES'] as num?)?.toInt(),
      confirmedCases: (json['CONFIRMED_CASES'] as num?)?.toInt(),
      severeCases: (json['SEVERE_CASES'] as num?)?.toInt(),
      deaths: (json['DEATHS'] as num?)?.toInt(),
      population: (json['POPULATION'] as num?)?.toInt(),
    );
  }
}

/// Model for a single record returned by the WHO Global Health Estimates
/// API (DEX_CMS/GHE_FULL_DD), filtered to the "Dengue" cause. Each record
/// is one country's estimated dengue death rate for one year — a second,
/// independent WHO data product (long-term mortality burden) alongside the
/// weekly surveillance counts above.
class DengueMortalityPoint {
  final String countryCode;
  final int year;
  final double deathRatePer100k;

  DengueMortalityPoint({
    required this.countryCode,
    required this.year,
    required this.deathRatePer100k,
  });

  factory DengueMortalityPoint.fromJson(Map<String, dynamic> json) {
    return DengueMortalityPoint(
      countryCode: json['DIM_COUNTRY_CODE'] as String? ?? '',
      year: int.tryParse('${json['DIM_YEAR_CODE']}') ?? 0,
      deathRatePer100k:
          double.tryParse('${json['VAL_DTHS_RATE100K_NUMERIC']}') ?? 0,
    );
  }
}
