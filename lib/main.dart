import 'package:flutter/material.dart';
import 'menu.dart';
import 'shared_data.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'widgets/custom_app_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SharedData()),
        ChangeNotifierProvider(create: (_) => VesselSelectionProvider()..init()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sensors Kinetics Clone',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'CustomFont',
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'CustomFont',
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const MenuPage(),
    );
  }
}
