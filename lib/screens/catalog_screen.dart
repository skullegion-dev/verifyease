import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import 'wallet_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _serviceController = TextEditingController();
  final AuthService _authService = AuthService();

  String countryQuery = '';
  String serviceQuery = '';
  bool confirmingPayment = false;

  String _usernameFromEmail(String? email) {
    if (email == null || email.isEmpty) return 'User';
    return email.split('@').first;
  }

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      Provider.of<AppProvider>(context, listen: false).fetchCountries();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoConfirmIfNeeded();
    });
  }

  @override
  void dispose() {
    _countryController.dispose();
    _serviceController.dispose();
    super.dispose();
  }

  Future<void> _autoConfirmIfNeeded() async {
    final uri = Uri.base;
    final payment = uri.queryParameters['payment'];
    final sessionId = uri.queryParameters['session_id'];

    if (payment != 'success' || sessionId == null || sessionId.isEmpty) {
      return;
    }

    if (confirmingPayment) return;

    setState(() => confirmingPayment = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('confirmTopUp');

      final result = await callable.call({'sessionId': sessionId});
      final data = result.data;
      final amount = data is Map ? data['amount'] : null;

      Fluttertoast.showToast(
        msg: amount != null
            ? 'Success! \$$amount added to wallet'
            : 'Payment confirmed',
        toastLength: Toast.LENGTH_LONG,
      );
    } on FirebaseFunctionsException catch (e) {
      if (!(e.message ?? '').toLowerCase().contains('already')) {
        Fluttertoast.showToast(
          msg: 'Confirm error: ${e.code} - ${e.message}',
          toastLength: Toast.LENGTH_LONG,
        );
      }
    } catch (_) {
      // Ignore redirect noise
    }

    if (mounted) {
      setState(() => confirmingPayment = false);
    }
  }

  Future<void> _buyNumber({
    required String countryCode,
    required Map service,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Fluttertoast.showToast(msg: 'Please login first');
      return;
    }

    Fluttertoast.showToast(msg: 'Buying number...');

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('buyNumber');

      final result = await callable.call({
        'country': countryCode,
        'product': service['name'],
        'operator': service['operator'] ?? 'any',
        'price': service['price'],
      });

      final data = result.data;
      final phone = data is Map ? data['phone'] : null;
      final activationId = data is Map ? data['activationId'] : null;
      final price = data is Map ? data['price'] : service['price'];

      if (phone != null && mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Number Purchased'),
            content: Text(
              'Phone: $phone\n'
              'ID: ${activationId ?? '-'}\n'
              'Price: \$$price\n\n'
              'Use this number for verification. SMS should arrive shortly.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        Fluttertoast.showToast(msg: 'Buy failed');
      }
    } on FirebaseFunctionsException catch (e) {
      Fluttertoast.showToast(
        msg: '${e.code}: ${e.message}',
        toastLength: Toast.LENGTH_LONG,
      );
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final user = FirebaseAuth.instance.currentUser;
    final username = _usernameFromEmail(user?.email);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'VerifyGlobally',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh catalog',
            onPressed: () {
              provider.countryServices.clear();
              provider.fetchCountries(force: true);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (user != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Text(
                'Welcome $username',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade800,
                ),
              ),
            ),
          if (user != null)
            StreamBuilder<double>(
              stream: _authService.walletBalanceStream(user.uid),
              builder: (context, snapshot) {
                final balance = snapshot.data ?? 0.0;
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.indigo,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Balance: \$${balance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (confirmingPayment)
                              const Text(
                                'Confirming payment...',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WalletScreen(),
                            ),
                          );
                        },
                        child: const Text('Add Funds'),
                      ),
                    ],
                  ),
                );
              },
            ),
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
          if (provider.lastError != null && provider.countries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Catalog error: ${provider.lastError}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.countries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('No countries loaded'),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () =>
                                  provider.fetchCountries(force: true),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
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
        final countryCode = (country['code'] ?? '').toString().toLowerCase();
        final isPriority =
            provider.priorityCountries.contains(countryCode);

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
                  child: Text('No numbers available'),
                )
              else
                ...matchingServices.map((service) {
                  final isPopular = service['isPopular'] == true;
                  final int qty = service['qty'] is int
                      ? service['qty'] as int
                      : int.tryParse('${service['qty']}') ?? 0;

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
                              'POPULAR',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '$qty available',
                      style: TextStyle(
                        color: stockColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\$${service['price']}',
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
                          onPressed: () => _buyNumber(
                            countryCode: countryCode,
                            service: service,
                          ),
                          child: const Text('Buy'),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}