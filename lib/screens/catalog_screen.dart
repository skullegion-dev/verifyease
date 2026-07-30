import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../providers/app_provider.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _serviceController = TextEditingController();

  String countryQuery = '';
  String serviceQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<AppProvider>(context, listen: false).fetchCountries();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'VerifyGlobally',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Country Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _countryController,
              decoration: InputDecoration(
                hintText: 'Search Country (e.g. USA, UK)...',
                prefixIcon: const Icon(Icons.public),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  countryQuery = value.toLowerCase().trim();
                });
              },
            ),
          ),

          // Service Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _serviceController,
              decoration: InputDecoration(
                hintText: 'Search Service (e.g. WhatsApp)...',
                prefixIcon: const Icon(Icons.apps),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  serviceQuery = value.toLowerCase().trim();
                });
              },
            ),
          ),

          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AppProvider provider) {
    final filteredCountries = provider.countries.where((country) {
      if (countryQuery.isEmpty) return true;
      final name = (country['name'] ?? '').toString().toLowerCase();
      final code = (country['code'] ?? '').toString().toLowerCase();
      return name.contains(countryQuery) || code.contains(countryQuery);
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: filteredCountries.length,
      itemBuilder: (context, index) {
        final country = filteredCountries[index];
        final countryCode = country['code'];
        final isPriority =
            provider.priorityCountries.contains(countryCode.toLowerCase());

        if (!provider.countryServices.containsKey(countryCode)) {
          provider.fetchServicesForCountry(countryCode);
        }

        final allServices = provider.countryServices[countryCode] ?? [];

        final matchingServices = allServices.where((service) {
          if (serviceQuery.isEmpty) return true;
          return service['name']
              .toString()
              .toLowerCase()
              .contains(serviceQuery);
        }).toList();

        if (serviceQuery.isNotEmpty && matchingServices.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: isPriority ? Colors.indigo.shade50 : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: ExpansionTile(
            initiallyExpanded:
                serviceQuery.isNotEmpty || countryQuery.isNotEmpty,
            leading: Text(
              country['flag'] ?? '🌍',
              style: const TextStyle(fontSize: 28),
            ),
            title: Text(
              country['name'] ?? countryCode,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isPriority ? Colors.indigo[800] : null,
              ),
            ),
            children: [
              if (provider.isLoadingServices && allServices.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (matchingServices.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text("No numbers available"),
                )
              else
                ...matchingServices.map((service) {
                  final isPopular = service['isPopular'] == true;
                  final int qty = service['qty'] ?? 0;

                  // Stock color
                  Color stockColor = Colors.green;
                  if (qty < 20) stockColor = Colors.orange;
                  if (qty < 5) stockColor = Colors.red;

                  return ListTile(
                    tileColor: isPopular ? Colors.amber.shade50 : null,
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            service['name'].toString().toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (isPopular)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "POPULAR",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      "$qty available",
                      style: TextStyle(
                        color: stockColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "\$${service['price']}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.indigo,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            Fluttertoast.showToast(msg: "Buying number...");
                            final result = await provider.buyNumber(
                              countryCode,
                              service['name'],
                              operator: service['operator'] ?? "any",
                            );

                            if (result != null && result['phone'] != null) {
                              Fluttertoast.showToast(
                                msg: "✅ ${result['phone']}",
                                toastLength: Toast.LENGTH_LONG,
                              );
                            } else {
                              Fluttertoast.showToast(msg: "❌ Failed to buy");
                            }
                          },
                          child: const Text("Buy"),
                        ),
                      ],
                    ),
                  );
                }).toList(),
            ],
          ),
        );
      },
    );
  }
}