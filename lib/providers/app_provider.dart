import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AppProvider extends ChangeNotifier {
  String apiToken = "PASTE_YOUR_5SIM_TOKEN_HERE"; // ← CHANGE THIS

  Map<String, double> priceCache = {};

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
    return 0.30;
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