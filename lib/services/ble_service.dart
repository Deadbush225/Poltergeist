import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService extends ChangeNotifier {
  static const String SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String CHARACTERISTIC_RX = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String DEVICE_NAME = "ESP32-S3 HID";

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rxCharacteristic;
  bool _isConnected = false;
  String _status = "Disconnected";

  bool get isConnected => _isConnected;
  String get status => _status;

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  Future<void> init() async {
    // Check adapter state
    if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.off) {
      _setStatus("Bluetooth is off");
      return;
    }
  }

  void _setStatus(String newStatus) {
    _status = newStatus;
    notifyListeners();
  }

  Future<void> startScan() async {
    _setStatus("Scanning...");
    
    try {
      // Scanning for all devices to ensure we find it.
      // Often devices don't advertise the service UUID in the main packet.
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );
    } catch (e) {
      _setStatus("Scan error: $e");
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Future<void> connect(BluetoothDevice device) async {
    await stopScan();
    _connectToDevice(device);
  }

  // Kept private for internal use, called by connect()
  Future<void> _connectToDevice(BluetoothDevice device) async {
    _setStatus("Connecting to ${device.platformName}...");
    try {
      await device.connect(autoConnect: false, license: License.free);
      _device = device;
      
      // Monitor connection state
      device.connectionState.listen((state) {
        _isConnected = state == BluetoothConnectionState.connected;
        if (!_isConnected) {
          _setStatus("Disconnected");
          _rxCharacteristic = null;
          notifyListeners();
        } else {
             _setStatus("Connected");
            notifyListeners();
        }
      });

      // After connect() returns, we are connected.
      // We must start discovery even if the listener callback hasn't fired yet.
      _isConnected = true; 
      await _discoverServices();
      
      
    } catch (e) {
      _setStatus("Connection error: $e");
    }
  }

  Future<void> _discoverServices() async {
    if (_device == null) return;
    
    try {
      List<BluetoothService> services = await _device!.discoverServices();
      debugPrint("Discovered ${services.length} services");
      
      for (BluetoothService service in services) {
        debugPrint("Service found: ${service.uuid.toString()}");
        
        // Use loose comparison to handle casing and format
        if (service.uuid.toString().toUpperCase().contains(SERVICE_UUID.substring(0, 8))) {
           debugPrint("Target Service Found!");
           for (BluetoothCharacteristic c in service.characteristics) {
            debugPrint("Char found: ${c.uuid.toString()}");
            if (c.uuid.toString().toUpperCase() == CHARACTERISTIC_RX || 
                c.uuid.toString().toUpperCase().contains(CHARACTERISTIC_RX.substring(0, 8))) { // Fallback check
              _rxCharacteristic = c;
              _setStatus("Ready");
              debugPrint("RX Characteristic Linked!");
              break;
            }
          }
        }
      }
      
      if (_rxCharacteristic == null) {
        debugPrint("Services scanned but RX not found. Target UUID was $SERVICE_UUID");
        _setStatus("Service found but RX characteristic missing");
      }
    } catch (e) {
      _setStatus("Service discovery error: $e");
    }
  }

  Future<void> disconnect() async {
    if (_device != null) {
      await _device!.disconnect();
    }
  }

  Future<void> sendCommand(String cmd, String payload) async {
    if (_rxCharacteristic == null) {
      debugPrint("Not connected or RX characteristic not found");
      return;
    }

    String message = "$cmd:$payload";
    try {
      // The ESP32 code expects string, we send bytes
      await _rxCharacteristic!.write(utf8.encode(message));
      debugPrint("Sent: $message");
    } catch (e) {
      debugPrint("Write error: $e");
      _setStatus("Send error: $e");
    }
  }
}
