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
    {"name": "United States", "code": "usa", "flag": "🇺🇸"},
    {"name": "United Kingdom", "code": "gb", "flag": "🇬🇧"},
    {"name": "Canada", "code": "canada", "flag": "🇨🇦"},
    {"name": "Australia", "code": "australia", "flag": "🇦🇺"},
    {"name": "Germany", "code": "germany", "flag": "🇩🇪"},
    {"name": "France", "code": "france", "flag": "🇫🇷"},
    {"name": "Italy", "code": "italy", "flag": "🇮🇹"},
    {"name": "Spain", "code": "spain", "flag": "🇪🇸"},
    {"name": "Netherlands", "code": "netherlands", "flag": "🇳🇱"},
    {"name": "Sweden", "code": "sweden", "flag": "🇸🇪"},
    {"name": "Norway", "code": "norway", "flag": "🇳🇴"},
    {"name": "Denmark", "code": "denmark", "flag": "🇩🇰"},
    {"name": "Finland", "code": "finland", "flag": "🇫🇮"},
    {"name": "Switzerland", "code": "switzerland", "flag": "🇨🇭"},
    {"name": "Austria", "code": "austria", "flag": "🇦🇹"},
    {"name": "Belgium", "code": "belgium", "flag": "🇧🇪"},
    {"name": "Ireland", "code": "ireland", "flag": "🇮🇪"},
    {"name": "India", "code": "india", "flag": "🇮🇳"},
    {"name": "Pakistan", "code": "pakistan", "flag": "🇵🇰"},
    {"name": "Bangladesh", "code": "bangladesh", "flag": "🇧🇩"},
    {"name": "Nigeria", "code": "nigeria", "flag": "🇳🇬"},
    {"name": "Kenya", "code": "kenya", "flag": "🇰🇪"},
    {"name": "South Africa", "code": "southafrica", "flag": "🇿🇦"},
    {"name": "Egypt", "code": "egypt", "flag": "🇪🇬"},
    {"name": "Brazil", "code": "brazil", "flag": "🇧🇷"},
    {"name": "Mexico", "code": "mexico", "flag": "🇲🇽"},
    {"name": "Argentina", "code": "argentina", "flag": "🇦🇷"},
    {"name": "Colombia", "code": "colombia", "flag": "🇨🇴"},
    {"name": "Chile", "code": "chile", "flag": "🇨🇱"},
    {"name": "Peru", "code": "peru", "flag": "🇵🇪"},
    {"name": "Russia", "code": "russia", "flag": "🇷🇺"},
    {"name": "Ukraine", "code": "ukraine", "flag": "🇺🇦"},
    {"name": "Poland", "code": "poland", "flag": "🇵🇱"},
    {"name": "Romania", "code": "romania", "flag": "🇷🇴"},
    {"name": "Greece", "code": "greece", "flag": "🇬🇷"},
    {"name": "Portugal", "code": "portugal", "flag": "🇵🇹"},
    {"name": "Turkey", "code": "turkey", "flag": "🇹🇷"},
    {"name": "Israel", "code": "israel", "flag": "🇮🇱"},
    {"name": "United Arab Emirates", "code": "uae", "flag": "🇦🇪"},
    {"name": "Saudi Arabia", "code": "saudiarabia", "flag": "🇸🇦"},
    {"name": "Qatar", "code": "qatar", "flag": "🇶🇦"},
    {"name": "Kuwait", "code": "kuwait", "flag": "🇰🇼"},
    {"name": "Japan", "code": "japan", "flag": "🇯🇵"},
    {"name": "South Korea", "code": "southkorea", "flag": "🇰🇷"},
    {"name": "Singapore", "code": "singapore", "flag": "🇸🇬"},
    {"name": "Malaysia", "code": "malaysia", "flag": "🇲🇾"},
    {"name": "Indonesia", "code": "indonesia", "flag": "🇮🇩"},
    {"name": "Thailand", "code": "thailand", "flag": "🇹🇭"},
    {"name": "Vietnam", "code": "vietnam", "flag": "🇻🇳"},
    {"name": "Philippines", "code": "philippines", "flag": "🇵🇭"},
    {"name": "Hong Kong", "code": "hongkong", "flag": "🇭🇰"},
    {"name": "New Zealand", "code": "newzealand", "flag": "🇳🇿"},
    {"name": "Morocco", "code": "morocco", "flag": "🇲🇦"},
    {"name": "Algeria", "code": "algeria", "flag": "🇩🇿"},
    {"name": "Ghana", "code": "ghana", "flag": "🇬🇭"},
    {"name": "Uganda", "code": "uganda", "flag": "🇺🇬"},
    {"name": "Tanzania", "code": "tanzania", "flag": "🇹🇿"},
  ];

  final List<String> products = ["any", "telegram", "whatsapp", "instagram", "gmail", "facebook", "twitter"];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('VerifyEase', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Wallet / Top-up coming soon')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.indigo.shade50,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search country or service...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: countries.length,
              itemBuilder: (context, index) {
                final country = countries[index];
                if (searchQuery.isNotEmpty && 
                    !country['name']!.toLowerCase().contains(searchQuery)) {
                  return const SizedBox.shrink();
                }

                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: Text(country['flag']!, style: const TextStyle(fontSize: 32)),
                    title: Text(country['name']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                    subtitle: const Text("Tap to see services"),
                    children: products.map((product) {
                      return FutureBuilder<double>(
                        future: provider.getSellingPrice(country['code']!, product),
                        builder: (context, snapshot) {
                          final price = snapshot.data ?? 0.35;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            title: Text(product.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text("Instant SMS • High quality", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("\$${price.toStringAsFixed(2)}", 
                                     style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () async {
                                    final result = await provider.buyNumber(country['code']!, product);
                                    if (result != null) {
                                      Fluttertoast.showToast(
                                        msg: "✅ Purchased! ID: ${result['id']}",
                                        backgroundColor: Colors.green,
                                        toastLength: Toast.LENGTH_LONG,
                                      );
                                    } else {
                                      Fluttertoast.showToast(msg: "❌ Failed to purchase", backgroundColor: Colors.red);
                                    }
                                  },
                                  child: const Text('Buy Now'),
                                ),
                              ],
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