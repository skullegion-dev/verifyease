import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/catalog_screen.dart';

void main() {
  runApp(const VerifyEase());
}

class VerifyEase extends StatelessWidget {
  const VerifyEase({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: 'VerifyEase',
        theme: ThemeData(primarySwatch: Colors.indigo),
        home: const CatalogScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
