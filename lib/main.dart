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
        title: 'VerifyGlobally - Buy Virtual Numbers',
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          useMaterial3: true,
        ),
        home: const CatalogScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}