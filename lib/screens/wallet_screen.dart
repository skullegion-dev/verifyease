import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final AuthService _authService = AuthService();
  final List<double> packages = [5, 10, 20, 50];
  double? selectedAmount;
  bool loading = false;

  Future<void> _payWithStripe() async {
    if (selectedAmount == null) {
      Fluttertoast.showToast(msg: 'Select an amount first');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Fluttertoast.showToast(msg: 'Please login first');
      return;
    }

    setState(() => loading = true);

    try {
      // IMPORTANT: same region as your deployed function
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('createCheckoutSession');

      final result = await callable.call({
        'amount': selectedAmount!.toInt(),
      });

      final data = result.data;
      final url = data is Map ? data['url'] as String? : null;

      if (url == null || url.isEmpty) {
        throw Exception('No checkout URL returned');
      }

      final uri = Uri.parse(url);
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        throw Exception('Could not open Stripe checkout');
      }

      Fluttertoast.showToast(
        msg: 'Complete payment in the browser. Balance updates automatically.',
        toastLength: Toast.LENGTH_LONG,
      );
    } on FirebaseFunctionsException catch (e) {
      Fluttertoast.showToast(
        msg: 'Payment error: ${e.code} - ${e.message}',
        toastLength: Toast.LENGTH_LONG,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: e.toString(),
        toastLength: Toast.LENGTH_LONG,
      );
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(child: Text('Please login'))
          : StreamBuilder<double>(
              stream: _authService.walletBalanceStream(user.uid),
              builder: (context, snapshot) {
                final balance = snapshot.data ?? 0.0;

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        color: Colors.indigo.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.account_balance_wallet,
                                size: 36,
                                color: Colors.indigo,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Current Balance',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                  Text(
                                    '\$${balance.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Add Funds',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Minimum top-up: \$5',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: packages.map((amount) {
                          final selected = selectedAmount == amount;
                          return ChoiceChip(
                            label: Text('\$${amount.toStringAsFixed(0)}'),
                            selected: selected,
                            onSelected: loading
                                ? null
                                : (_) {
                                    setState(() {
                                      selectedAmount = amount;
                                    });
                                  },
                            selectedColor: Colors.indigo,
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Payment Method',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.credit_card,
                            color: Colors.indigo,
                          ),
                          title: const Text(
                            'Card / Apple Pay / Google Pay',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text('Pay securely with Stripe'),
                          trailing: loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: loading ? null : _payWithStripe,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'PayPal and Crypto will be added next.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}