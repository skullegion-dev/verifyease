import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class AppProvider extends ChangeNotifier {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  List<Map<String, dynamic>> countries = [];
  Map<String, List<Map<String, dynamic>>> countryServices = {};
  final Set<String> _loadingCountryCodes = {};

  bool isLoading = false;
  bool isLoadingServices = false;
  String? lastError;

  final List<String> priorityCountries = [
    'usa',
    'canada',
    'australia',
    'england',
    'italy',
    'france',
    'germany',
  ];

  Future<void> fetchCountries({bool force = false}) async {
    if (countries.isNotEmpty && !force) return;

    isLoading = true;
    lastError = null;
    notifyListeners();

    try {
      final result = await _functions.httpsCallable('getCountries').call();
      final data = result.data;

      final list = (data is Map && data['countries'] is List)
          ? List<dynamic>.from(data['countries'] as List)
          : <dynamic>[];

      final tempCountries = list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final code = (map['code'] ?? '').toString().toLowerCase();
        String displayName = (map['name'] ?? code).toString();
        if (code == 'england') displayName = 'UK';
        return {
          'code': code,
          'name': displayName,
          'flag': _getFlag(code),
        };
      }).toList();

      tempCountries.sort((a, b) {
        final aCode = a['code'].toString().toLowerCase();
        final bCode = b['code'].toString().toLowerCase();
        final aIsPriority = priorityCountries.contains(aCode);
        final bIsPriority = priorityCountries.contains(bCode);

        if (aIsPriority && !bIsPriority) return -1;
        if (!aIsPriority && bIsPriority) return 1;
        if (aIsPriority && bIsPriority) {
          return priorityCountries
              .indexOf(aCode)
              .compareTo(priorityCountries.indexOf(bCode));
        }
        return a['name'].toString().compareTo(b['name'].toString());
      });

      countries = tempCountries;
    } on FirebaseFunctionsException catch (e) {
      lastError = '${e.code}: ${e.message}';
      debugPrint('Error fetching countries: $lastError');
      countries = [];
    } catch (e) {
      lastError = e.toString();
      debugPrint('Error fetching countries: $e');
      countries = [];
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> fetchServicesForCountry(String countryCode) async {
    final code = countryCode.toLowerCase();
    if (countryServices.containsKey(code) ||
        _loadingCountryCodes.contains(code)) {
      return;
    }

    _loadingCountryCodes.add(code);
    isLoadingServices = true;
    notifyListeners();

    try {
      final result = await _functions.httpsCallable('getProducts').call({
        'country': code,
      });
      final data = result.data;

      final list = (data is Map && data['products'] is List)
          ? List<dynamic>.from(data['products'] as List)
          : <dynamic>[];

      final services = list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return {
          'name': (map['name'] ?? '').toString().toLowerCase(),
          'cost': map['cost'],
          'price': map['price'],
          'qty': map['qty'] ?? 0,
          'operator': map['operator'] ?? 'any',
          'rate': map['rate'] ?? 0,
          'isPopular': map['isPopular'] == true,
        };
      }).toList();

      countryServices[code] = services;
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
          'Error fetching services for $code: ${e.code} ${e.message}');
      countryServices[code] = [];
    } catch (e) {
      debugPrint('Error fetching services for $code: $e');
      countryServices[code] = [];
    }

    _loadingCountryCodes.remove(code);
    isLoadingServices = _loadingCountryCodes.isNotEmpty;
    notifyListeners();
  }

  String _getFlag(String code) {
    const flagMap = {
      'usa': '🇺🇸',
      'england': '🇬🇧',
      'canada': '🇨🇦',
      'germany': '🇩🇪',
      'france': '🇫🇷',
      'india': '🇮🇳',
      'brazil': '🇧🇷',
      'nigeria': '🇳🇬',
      'russia': '🇷🇺',
      'ukraine': '🇺🇦',
      'indonesia': '🇮🇩',
      'philippines': '🇵🇭',
      'spain': '🇪🇸',
      'italy': '🇮🇹',
      'netherlands': '🇳🇱',
      'poland': '🇵🇱',
      'turkey': '🇹🇷',
      'australia': '🇦🇺',
      'mexico': '🇲🇽',
      'argentina': '🇦🇷',
      'colombia': '🇨🇴',
      'chile': '🇨🇱',
      'peru': '🇵🇪',
      'vietnam': '🇻🇳',
      'thailand': '🇹🇭',
      'malaysia': '🇲🇾',
      'singapore': '🇸🇬',
      'hongkong': '🇭🇰',
      'japan': '🇯🇵',
      'southkorea': '🇰🇷',
      'china': '🇨🇳',
      'pakistan': '🇵🇰',
      'bangladesh': '🇧🇩',
      'egypt': '🇪🇬',
      'southafrica': '🇿🇦',
      'kenya': '🇰🇪',
      'ghana': '🇬🇭',
      'morocco': '🇲🇦',
      'portugal': '🇵🇹',
      'sweden': '🇸🇪',
      'romania': '🇷🇴',
      'czech': '🇨🇿',
      'hungary': '🇭🇺',
      'greece': '🇬🇷',
      'israel': '🇮🇱',
      'uae': '🇦🇪',
      'saudiarabia': '🇸🇦',
    };
    return flagMap[code.toLowerCase()] ?? '🌍';
  }
}