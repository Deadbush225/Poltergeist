import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';

class KeyboardScreen extends StatefulWidget {
  const KeyboardScreen({super.key});

  @override
  State<KeyboardScreen> createState() => _KeyboardScreenState();
}

class _KeyboardScreenState extends State<KeyboardScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _macros = ["Hello World", "ls -la\n", "exit\n", "sudo suo\n"]; // Example macros

  void _sendText(String text) {
    if (text.isEmpty) return;
    context.read<BleService>().sendCommand("TYPE", text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Real-time typing area
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: "Type to send...",
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {
                   _sendText(_controller.text);
                   _controller.clear();
                },
              ),
            ),
            onChanged: (val) {
               // Optional: Live typing logic here
            },
            onSubmitted: (val) {
              _sendText(val);
              _controller.clear();
            },
            textInputAction: TextInputAction.send,
          ),
        ),
        
        const Divider(),
        
        // Quick Actions / Macros
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text("Quick Actions", style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _macros.map((macro) => ActionChip(
                  label: Text(macro.replaceAll("\n", "⏎")),
                  onPressed: () => _sendText(macro),
                )).toList(),
              ),
              const SizedBox(height: 16),
               
              // Modifiers Visual Placeholder (Since FW doesn't support them explicitly yet)
              Text("Modifiers (FW update required)", style: Theme.of(context).textTheme.bodySmall),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _modifierButton("CTRL"),
                  _modifierButton("ALT"),
                  _modifierButton("SHIFT"),
                  _modifierButton("GUI"),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _modifierButton(String label) {
    return  OutlinedButton(
      onPressed: () {
        // Placeholder for modifier logic
        // context.read<BleService>().sendCommand("MOD", label); 
      },
      child: Text(label),
    );
  }
}
