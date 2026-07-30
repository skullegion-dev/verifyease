import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  final List<Map<String, String>> countries = [
    {"name": "United States", "code": "usa"},
    {"name": "United Kingdom", "code": "gb"},
    {"name": "Canada", "code": "canada"},
    {"name": "Germany", "code": "germany"},
    {"name": "France", "code": "france"},
    {"name": "India", "code": "india"},
    {"name": "Brazil", "code": "brazil"},
    {"name": "Nigeria", "code": "nigeria"},
  ];

  final List<String> products = ["any", "telegram", "whatsapp", "instagram", "gmail"];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('VerifyEase - Buy Numbers')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search country...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: countries.length,
              itemBuilder: (context, index) {
                final country = countries[index];
                if (searchQuery.isNotEmpty && !country['name']!.toLowerCase().contains(searchQuery)) {
                  return const SizedBox.shrink();
                }
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ExpansionTile(
                    title: Text(country['name']!),
                    children: products.map((product) {
                      return FutureBuilder<double>(
                        future: provider.getSellingPrice(country['code']!, product),
                        builder: (context, snapshot) {
                          final price = snapshot.data ?? 0.30;
                          return ListTile(
                            title: Text(product.toUpperCase()),
                            subtitle: Text("\utf8{price.toStringAsFixed(2)}"),
                            trailing: ElevatedButton(
                              onPressed: () async {
                                final result = await provider.buyNumber(country['code']!, product);
                                if (result != null) {
                                  Fluttertoast.showToast(msg: "Success! ID: \");
                                } else {
                                  Fluttertoast.showToast(msg: "Purchase failed");
                                }
                              },
                              child: const Text('Buy'),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
