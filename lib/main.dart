import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
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
  VoidCallback? _bleListener;
  bool _bleListenerRegistered = false;
  static const MethodChannel _settingsChannel = MethodChannel('epayload/settings');
  bool? _prevAdapterOn;

  void _showBluetoothOffSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Bluetooth appears to be off. Please enable Bluetooth.'),
        action: SnackBarAction(
          label: 'Open Bluetooth Settings',
          onPressed: () async {
            try {
              await _settingsChannel.invokeMethod('openBluetoothSettings');
            } catch (e) {
              // Fallback to open app settings
              openAppSettings();
            }
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkPermissions();
  }

  @override
  void dispose() {
    if (_bleListener != null) {
      try {
        context.read<BleService>().removeListener(_bleListener!);
      } catch (_) {}
    }
    _tabController.dispose();
    super.dispose();
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

    // Register a simple listener to show a Snackbar when Bluetooth is off or scan failed.
    // We keep a previous status to avoid spamming the Snackbar repeatedly.
    _bleListener ??= () {
      final adapterOn = bleService.isAdapterOn;
      if (_prevAdapterOn == null || adapterOn != _prevAdapterOn) {
        _prevAdapterOn = adapterOn;
        if (!adapterOn) {
          _showBluetoothOffSnackBar();
        } else {
          // Bluetooth just became available - clear any previous warnings
          ScaffoldMessenger.of(context).clearSnackBars();
        }
      }
    };
    if (!_bleListenerRegistered) {
      bleService.addListener(_bleListener!);
      _bleListenerRegistered = true;
    }

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
                 if (!bleService.isAdapterOn) {
                   _showBluetoothOffSnackBar();
                 } else {
                   _showScanDialog(context);
                 }
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
