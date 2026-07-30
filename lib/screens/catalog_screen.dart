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

  @override
  void initState() {
    super.initState();
    Provider.of<AppProvider>(context, listen: false).fetchCountries();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isWeb = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VerifyEase', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () => _showWallet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search country or service...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
            ),
          ),

          // Loading
          if (provider.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator())),

          // Countries List
          if (!provider.isLoading)
            Expanded(
              child: provider.countries.isEmpty
                  ? const Center(child: Text("No countries loaded"))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: provider.countries.length,
                      itemBuilder: (context, index) {
                        final country = provider.countries[index];
                        if (searchQuery.isNotEmpty && 
                            !country['name'].toString().toLowerCase().contains(searchQuery)) {
                          return const SizedBox.shrink();
                        }

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ExpansionTile(
                            leading: Text(country['flag'] ?? '🌍', style: const TextStyle(fontSize: 32)),
                            title: Text(country['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                            children: ["any", "telegram", "whatsapp", "instagram", "gmail"]
                                .map((product) => _buildServiceTile(provider, country['code'], product))
                                .toList(),
                          ),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildServiceTile(AppProvider provider, String countryCode, String product) {
    return FutureBuilder<double>(
      future: provider.getSellingPrice(countryCode, product),
      builder: (context, snapshot) {
        final price = snapshot.data ?? 0.35;
        return ListTile(
          title: Text(product.toUpperCase()),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("\$${price.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () async {
                  final result = await provider.buyNumber(countryCode, product);
                  if (result != null) {
                    Fluttertoast.showToast(msg: "✅ Purchased! ID: ${result['id']}");
                  } else {
                    Fluttertoast.showToast(msg: "❌ Failed");
                  }
                },
                child: const Text("Buy"),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showWallet(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Wallet"),
        content: const Text("Top-up with Stripe/PayPal coming soon."),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }
}