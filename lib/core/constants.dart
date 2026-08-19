export 'demo_data.dart';

/// Heat-alarm ORANGE threshold in °C — cabin heating into a dangerous
/// range. Must match firmware TEMP_THRESHOLD in Project_1_draft_v3.ino.
const double kHeatOrangeThresholdC = 38.0;

/// Heat-alarm RED threshold in °C — cabin heat is at/above the range
/// associated with heatstroke onset (~40°C core) and approaching a
/// lethal core temperature (~42°C+). Above this, tier escalates to
/// CRITICAL immediately.
const double kHeatRedThresholdC = 42.0;

/// Alias kept for screens that only need a single "is this hot" line
/// (home severity pill, temperature graph danger line, contacts list).
/// Points at the earlier (orange) threshold.
const double kHeatThresholdC = kHeatOrangeThresholdC;

/// BLE advertised name of the ESP32 seat (must match firmware `BLE_SEAT_NAME`).
const String kBleSeatName = 'WabySeat';

/// RSSI (dBm) at or above this → caregiver Near.
/// Measured in-car at 1.5 m: raw −70 to −76, median ~−73.
const int kBleRssiNearDbm = -74;

/// RSSI (dBm) at or below this → caregiver Far.
const int kBleRssiFarDbm = -80;

/// No WabySeat advertisement for this long, after having seen it → Far.
const Duration kBleLostAfter = Duration(seconds: 4);

const List<String> kGenderOptions = ['Boy', 'Girl'];

const List<String> kCountryOptions = [
  'Australia',
  'Brunei',
  'Cambodia',
  'Canada',
  'China',
  'India',
  'Indonesia',
  'Japan',
  'Laos',
  'Malaysia',
  'Myanmar',
  'Philippines',
  'Saudi Arabia',
  'Singapore',
  'South Korea',
  'Thailand',
  'United Arab Emirates',
  'United Kingdom',
  'United States',
  'Vietnam',
];

class CountryDialCode {
  final String name;
  final String dialCode; // e.g. '+60'
  const CountryDialCode(this.name, this.dialCode);
}

const kDefaultDialCode = '+60'; // Malaysia default

const List<CountryDialCode> kCountryDialCodes = [
  CountryDialCode('Australia', '+61'),
  CountryDialCode('Brunei', '+673'),
  CountryDialCode('Cambodia', '+855'),
  CountryDialCode('Canada', '+1'),
  CountryDialCode('China', '+86'),
  CountryDialCode('India', '+91'),
  CountryDialCode('Indonesia', '+62'),
  CountryDialCode('Japan', '+81'),
  CountryDialCode('Laos', '+856'),
  CountryDialCode('Malaysia', '+60'),
  CountryDialCode('Myanmar', '+95'),
  CountryDialCode('Philippines', '+63'),
  CountryDialCode('Saudi Arabia', '+966'),
  CountryDialCode('Singapore', '+65'),
  CountryDialCode('South Korea', '+82'),
  CountryDialCode('Thailand', '+66'),
  CountryDialCode('United Arab Emirates', '+971'),
  CountryDialCode('United Kingdom', '+44'),
  CountryDialCode('United States', '+1'),
  CountryDialCode('Vietnam', '+84'),
];

const List<String> kCarColorOptions = [
  '#0F2D54', // Navy
  '#3B74BC', // Blue
  '#56B337', // Green
  '#C2291D', // Red
  '#E08D3C', // Orange
  '#E0C23C', // Yellow
  '#7C5CBF', // Purple
  '#D6608A', // Pink
  '#1E9C8B', // Teal
  '#6B7280', // Grey
  '#1A1A1A', // Black
  '#FFFFFF', // White
];
