import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AppProvider extends ChangeNotifier {
  String apiToken = "eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE4MTY5NTMzOTgsImlhdCI6MTc4NTQxNzM5OCwicmF5IjoiOTVmOWNmNWJjYzQ3OTU3OTQyYjE3YzY4YWQxY2Q5YjAiLCJzdWIiOjQzODQwNzR9.feZlZ1SmsoZAmepLceSz76czXBZu57AjlEhE7XK0H5fR-4xt4muwz19d8VYW730DsP0u-y_AwcC4fr9gE0GQldCIiMmtCwD8neD1rahqSgWdFx0cVfA8p_CzIZnawEJ2zuEK9VS9JVEP0-JsonvqpB2h42PXFKNHUG52Ytdx1BWU6nnThuO6sGqhg0ddrKNKxFUBnqVKyKICWS-dZ1WVwGioRi1kVS6xSKGHoO7dJZKh3Zunypy6TbqDx_2eGQOL0KVAJ53RSn1OvhcA-YePI9X68HlP0Cv9Ac4YI8oVRSQV7PizDGMnQIdxqbKcQz_qZaPPEhHFWFuNbQFjEXAL_A"; // ← Change this

  Map<String, double> priceCache = {};
  List<dynamic> countries = [];
  Map<String, List<String>> services = {};

  bool isLoading = false;

  // Fetch all countries
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
        countries = data.keys.map((key) {
          return {
            "code": key,
            "name": data[key]['text_en'] ?? key.toUpperCase(),
            "flag": _getFlag(key),
          };
        }).toList();

        // Sort alphabetically
        countries.sort((a, b) => a['name'].compareTo(b['name']));
      }
    } catch (e) {
      print("Error fetching countries: $e");
    }

    isLoading = false;
    notifyListeners();
  }

  String _getFlag(String code) {
    // Simple flag mapping (you can expand)
    const flagMap = {
      'usa': '🇺🇸', 'gb': '🇬🇧', 'canada': '🇨🇦', 'germany': '🇩🇪',
      'france': '🇫🇷', 'india': '🇮🇳', 'brazil': '🇧🇷', 'nigeria': '🇳🇬',
    };
    return flagMap[code] ?? '🌍';
  }

  // Keep your existing methods
  Future<double> getSellingPrice(String country, String product) async {
    String key = "$country-$product";
    if (priceCache.containsKey(key)) return priceCache[key]! * 1.5;

    try {
      final url = Uri.parse('https://5sim.net/v1/user/buy/activation/$country/any/$product');
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $apiToken',
        'Accept': 'application/json',
      });

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        double cost = (data['price'] ?? 0.15).toDouble();
        double yourPrice = cost * 1.5;
        priceCache[key] = cost;
        return double.parse(yourPrice.toStringAsFixed(2));
      }
    } catch (e) {
      print("Price error: $e");
    }
    return 0.35;
  }

  Future<Map<String, dynamic>?> buyNumber(String country, String product) async {
    try {
      final url = Uri.parse('https://5sim.net/v1/user/buy/activation/$country/any/$product');
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $apiToken',
        'Accept': 'application/json',
      });

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      print("Buy error: $e");
    }
    return null;
  }
}