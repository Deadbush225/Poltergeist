import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/ble_service.dart';
import 'screens/mouse_screen.dart';
import 'screens/keyboard_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BleService()),
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
      title: 'ESP32 HID Controller',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    
    // Initialize BLE after permissions
    if (mounted) {
        context.read<BleService>().init();
    }
  }

  void _showScanDialog(BuildContext context) {
    final bleService = context.read<BleService>();
    bleService.startScan();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Available Devices"),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<List<dynamic>>( // Using dynamic to avoid direct ScanResult import issues if not explicit
            stream: bleService.scanResults,
            builder: (ctx, snapshot) {
              if (snapshot.hasError) return Text("Error: ${snapshot.error}");
              
              final results = snapshot.data ?? [];
              
              if (results.isEmpty) {
                return const Center(child: Text("Scanning..."));
              }

              return ListView.builder(
                itemCount: results.length,
                itemBuilder: (ctx, index) {
                  final r = results[index];
                  // If name is empty, show ID, else show name
                  final name = r.device.platformName.isNotEmpty ? r.device.platformName : "Unknown Device";
                  final id = r.device.remoteId.toString();
                  final rssi = r.rssi;
                  
                  return ListTile(
                    title: Text(name),
                    subtitle: Text("$id (RSSI: $rssi)"),
                    onTap: () {
                      bleService.connect(r.device);
                      Navigator.of(ctx).pop();
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              bleService.stopScan();
              Navigator.of(ctx).pop();
            },
            child: const Text("Cancel"),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              bleService.stopScan().then((_) => bleService.startScan()); // Restart scan
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bleService = context.watch<BleService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("ESP32 HID Remote"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.keyboard), text: "Keyboard"),
            Tab(icon: Icon(Icons.mouse), text: "Mouse"),
          ],
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(bleService.status, style: const TextStyle(fontSize: 12)),
            ),
          ),
          IconButton(
            icon: Icon(bleService.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled),
            onPressed: () {
               if (!bleService.isConnected) {
                 _showScanDialog(context);
               } else {
                 bleService.disconnect();
               }
            },
          )
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // Disable swipe to switch tabs
        children: const [
          KeyboardScreen(),
          MouseScreen(),
        ],
      ),
    );
  }
}
