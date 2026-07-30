import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AppProvider extends ChangeNotifier {
  // ⚠️ Put your real 5SIM token here
  String apiToken = "eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE4MTY5NTQ2ODMsImlhdCI6MTc4NTQxODY4MywicmF5IjoiOTVmOWNmNWJjYzQ3OTU3OTQyYjE3YzY4YWQxY2Q5YjAiLCJzdWIiOjQzODQwNzR9.NSNE1LkgLa9dp5nP_8kWMuqau-YdHD-0GLrYCjphgFOQCq2St9LYr-SX3M9_cPcrUSAWUfeTo136xDESXpX4iOSwXCatzcVgw8TD_1lzKqxKbYbWt6yXqiYBHq3hFpxkyzOuyuUuuFZvBYWcFDVH1An5qbGe8vkSYCCJqU3F2YCLSkSQuwZ5nLKmd9DAq3Wvs0UyZO8H3Yo3f_9sGTmKMxThTnSC9AcWkM_apHvv9xmUCog_fsDT1UoKLIOuM1XvzhKsg3eiUCpq5Uv_peY9HoL5zLt1tstBUZvBmHvFTUalEZKn9HjMOZmabT4-PCO1kkhq2XbcVACfInHJ6iHh0A";

  List<dynamic> countries = [];
  Map<String, List<Map<String, dynamic>>> countryServices = {};
  bool isLoading = false;
  bool isLoadingServices = false;

  final List<String> priorityCountries = [
    'usa',
    'canada',
    'australia',
    'england',
    'italy',
    'france',
    'germany',
  ];

  Future<void> fetchCountries() async {
    if (countries.isNotEmpty) return;

    isLoading = true;
    notifyListeners();

    try {
      final res = await http.get(
        Uri.parse('https://5sim.net/v1/guest/countries'),
        headers: {'Accept': 'application/json'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;

        List<dynamic> tempCountries = data.keys.map((key) {
          String displayName = data[key]['text_en'] ?? key.toUpperCase();

          if (key.toLowerCase() == 'england') {
            displayName = 'UK';
          }

          return {
            "code": key,
            "name": displayName,
            "flag": _getFlag(key),
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

          return a['name'].compareTo(b['name']);
        });

        countries = tempCountries;
      }
    } catch (e) {
      print("Error fetching countries: $e");
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> fetchServicesForCountry(String countryCode) async {
    if (countryServices.containsKey(countryCode)) return;

    isLoadingServices = true;
    notifyListeners();

    try {
      final productsUrl =
          Uri.parse('https://5sim.net/v1/guest/products/$countryCode/any');
      final productsRes =
          await http.get(productsUrl, headers: {'Accept': 'application/json'});

      if (productsRes.statusCode != 200) {
        isLoadingServices = false;
        notifyListeners();
        return;
      }

      final productsData =
          jsonDecode(productsRes.body) as Map<String, dynamic>;

      final pricesUrl =
          Uri.parse('https://5sim.net/v1/guest/prices?country=$countryCode');
      final pricesRes =
          await http.get(pricesUrl, headers: {'Accept': 'application/json'});

      Map<String, dynamic> pricesData = {};
      if (pricesRes.statusCode == 200) {
        final decoded = jsonDecode(pricesRes.body);
        if (decoded is Map && decoded.containsKey(countryCode)) {
          pricesData = decoded[countryCode];
        }
      }

      List<Map<String, dynamic>> services = [];

      productsData.forEach((serviceName, info) {
        final int qty = info['Qty'] ?? 0;

        if (info['Category'] == 'activation' && qty > 0) {
          double bestCost = (info['Price'] ?? 0.25).toDouble();
          String bestOperator = "any";
          double bestRate = 0;

          if (pricesData.containsKey(serviceName)) {
            final operators = pricesData[serviceName] as Map<String, dynamic>;

            operators.forEach((operatorName, operatorInfo) {
              double cost = (operatorInfo['cost'] ?? 999).toDouble();
              int count = operatorInfo['count'] ?? 0;
              double rate = (operatorInfo['rate'] ?? 0).toDouble();

              if (count > 0) {
                if (rate > bestRate) {
                  bestRate = rate;
                  bestCost = cost;
                  bestOperator = operatorName;
                } else if (rate == bestRate && cost < bestCost) {
                  bestCost = cost;
                  bestOperator = operatorName;
                }
              }
            });
          }

          double sellingPrice = bestCost * 1.5;

          services.add({
            "name": serviceName,
            "cost": bestCost,
            "price": double.parse(sellingPrice.toStringAsFixed(2)),
            "qty": qty,
            "operator": bestOperator,
            "rate": bestRate,
            "isPopular": _isPopularService(serviceName),
          });
        }
      });

      services.sort((a, b) {
        if (a['isPopular'] && !b['isPopular']) return -1;
        if (!a['isPopular'] && b['isPopular']) return 1;
        return a['name'].compareTo(b['name']);
      });

      countryServices[countryCode] = services;
    } catch (e) {
      print("Error fetching services: $e");
    }

    isLoadingServices = false;
    notifyListeners();
  }

  bool _isPopularService(String name) {
    const popular = [
      'telegram',
      'whatsapp',
      'google',
      'instagram',
      'facebook',
      'tiktok',
      'discord',
      'twitter',
      'amazon',
      'microsoft',
    ];
    return popular.contains(name.toLowerCase());
  }

  Future<Map<String, dynamic>?> buyNumber(
    String country,
    String product, {
    String operator = "any",
  }) async {
    try {
      final url = Uri.parse(
        'https://5sim.net/v1/user/buy/activation/$country/$operator/$product',
      );

      final res = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $apiToken',
          'Accept': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        print("Buy failed: ${res.body}");
      }
    } catch (e) {
      print("Buy error: $e");
    }
    return null;
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