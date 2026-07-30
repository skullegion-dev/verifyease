import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
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
                            onSelected: (_) {
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

                      _paymentButton(
                        title: 'Card / Apple Pay / Google Pay',
                        subtitle: 'Stripe',
                        icon: Icons.credit_card,
                        onTap: () {
                          if (selectedAmount == null) {
                            Fluttertoast.showToast(msg: 'Select an amount first');
                            return;
                          }
                          Fluttertoast.showToast(
                            msg:
                                'Stripe coming next. Selected \$${selectedAmount!.toStringAsFixed(0)}',
                          );
                        },
                      ),
                      _paymentButton(
                        title: 'PayPal',
                        subtitle: 'Pay with PayPal balance or card',
                        icon: Icons.account_balance,
                        onTap: () {
                          if (selectedAmount == null) {
                            Fluttertoast.showToast(msg: 'Select an amount first');
                            return;
                          }
                          Fluttertoast.showToast(
                            msg:
                                'PayPal coming next. Selected \$${selectedAmount!.toStringAsFixed(0)}',
                          );
                        },
                      ),
                      _paymentButton(
                        title: 'Crypto',
                        subtitle: 'USDT, BTC, ETH and more',
                        icon: Icons.currency_bitcoin,
                        onTap: () {
                          if (selectedAmount == null) {
                            Fluttertoast.showToast(msg: 'Select an amount first');
                            return;
                          }
                          Fluttertoast.showToast(
                            msg:
                                'Crypto coming next. Selected \$${selectedAmount!.toStringAsFixed(0)}',
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _paymentButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: Colors.indigo),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}