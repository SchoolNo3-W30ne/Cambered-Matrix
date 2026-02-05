import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:typed_data';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  windowManager.setTitle('MatrixMini Control');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MatrixMini Control',
      theme: ThemeData.dark(),
      home: const ControlScreen(),
    );
  }
}

class ControlScreen extends StatefulWidget {
  const ControlScreen({Key? key}) : super(key: key);

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription? _subscription;

  int _speed = 100;
  final int _speedStep = 10;
  String _lastKey = '';
  String _arduinoResponse = '';
  bool _isConnected = false;
  String _serialPort = '';

  final int _baudRate = 9600;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPortDialog();
    });
  }

  Future<void> _showPortDialog() async {
    final TextEditingController portController = TextEditingController();

    final availablePorts = SerialPort.availablePorts;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: const Text(
            'Введите порт:',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: portController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'COM1',
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF141428),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.cyan),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.cyan.withOpacity(0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.cyan, width: 2),
                  ),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    Navigator.of(context).pop();
                    _serialPort = value;
                    _connectToPort();
                  }
                },
              ),

              const SizedBox(height: 16),

              if (availablePorts.isNotEmpty) ...[
                const Text(
                  'Доступные порты:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: SingleChildScrollView(
                    child: Column(
                      children: availablePorts.map((port) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: InkWell(
                            onTap: () {
                              portController.text = port;
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF141428),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.cyan.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.usb,
                                    size: 16,
                                    color: Colors.cyan,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    port,
                                    style: const TextStyle(
                                      color: Colors.cyan,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ] else
                const Text(
                  'Нет доступных портов',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Future.delayed(const Duration(milliseconds: 100), () {
                  _showPortDialog();
                });
              },
              child: const Text(
                'Отмена',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                if (portController.text.isNotEmpty) {
                  Navigator.of(context).pop();
                  _serialPort = portController.text;
                  _connectToPort();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Введите имя порта'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Подключить'),
            ),
          ],
        );
      },
    );
  }

  void _connectToPort() async {
    try {
      // Проверяем список доступных портов
      final availablePorts = SerialPort.availablePorts;
      print('Доступные порты: $availablePorts');

      if (!availablePorts.contains(_serialPort)) {
        _showError(
          'Порт $_serialPort не найден!\nДоступные: ${availablePorts.join(", ")}',
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          _showPortDialog();
        });
        return;
      }

      _port = SerialPort(_serialPort);
      // Добавляем задержку перед открытием
      await Future.delayed(const Duration(milliseconds: 100));

      if (!_port!.openReadWrite()) {
        // Выводим детальную ошибку
        final error = SerialPort.lastError;
        print(
          'Ошибка открытия порта: errno=${error?.errorCode}, message=${error?.message}',
        );

        _showError(
          'Не удалось открыть порт $_serialPort\n'
          'Ошибка: ${error?.message ?? "неизвестная"}\n'
          'Код: ${error?.errorCode}\n\n'
          'Закройте все программы, использующие этот порт',
        );

        Future.delayed(const Duration(milliseconds: 500), () {
          _showPortDialog();
        });
        return;
      }

      final config = SerialPortConfig();
      config.baudRate = _baudRate;
      config.bits = 8;
      config.stopBits = 1;
      config.parity = SerialPortParity.none;
      _port!.config = config;

      _reader = SerialPortReader(_port!);
      _subscription = _reader!.stream.listen((Uint8List data) {
        setState(() {
          _arduinoResponse = String.fromCharCodes(data).trim();
        });
        print('Arduino: $_arduinoResponse');
      });

      setState(() {
        _isConnected = true;
      });

      print('MatrixMini подключен на $_serialPort');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Подключено к $_serialPort'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError('Ошибка подключения: $e');
      Future.delayed(const Duration(milliseconds: 500), () {
        _showPortDialog();
      });
    }
  }

  void _sendMotors(int m1, int m2) {
    if (_port == null || !_isConnected) return;

    String cmd = 'm1 $m1 m2 $m2\n';
    _port!.write(Uint8List.fromList(cmd.codeUnits));
    print(cmd.trim());
  }

  void _sendStop() {
    if (_port == null || !_isConnected) return;
    _port!.write(Uint8List.fromList('stop\n'.codeUnits));
    print('stop');
  }

  void _changeSpeed(int delta) {
    setState(() {
      _speed = (_speed + delta).clamp(10, 100);
    });
    if (_port != null && _isConnected) {
      String cmd = 'speed $_speed\n';
      _port!.write(Uint8List.fromList(cmd.codeUnits));
      print('Скорость: $_speed');
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _changeSpeed(_speedStep);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _changeSpeed(-_speedStep);
      } else if (event.logicalKey == LogicalKeyboardKey.space) {
        _sendStop();
        setState(() {
          _lastKey = '';
        });
      }

      if (event.logicalKey == LogicalKeyboardKey.keyW) {
        _sendMotors(_speed, _speed);
        setState(() {
          _lastKey = 'W';
        });
      } else if (event.logicalKey == LogicalKeyboardKey.keyS) {
        _sendMotors(-_speed, -_speed);
        setState(() {
          _lastKey = 'S';
        });
      } else if (event.logicalKey == LogicalKeyboardKey.keyA) {
        _sendMotors(-_speed, _speed);
        setState(() {
          _lastKey = 'A';
        });
      } else if (event.logicalKey == LogicalKeyboardKey.keyD) {
        _sendMotors(_speed, -_speed);
        setState(() {
          _lastKey = 'D';
        });
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyW ||
          event.logicalKey == LogicalKeyboardKey.keyS ||
          event.logicalKey == LogicalKeyboardKey.keyA ||
          event.logicalKey == LogicalKeyboardKey.keyD) {
        if (_lastKey.isNotEmpty) {
          _sendStop();
          setState(() {
            _lastKey = '';
          });
        }
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _reconnect() {
    _subscription?.cancel();
    _reader?.close();
    _port?.close();
    _port?.dispose();

    setState(() {
      _isConnected = false;
      _serialPort = '';
      _lastKey = '';
    });

    _showPortDialog();
  }

  @override
  void dispose() {
    _sendStop();
    _subscription?.cancel();
    _reader?.close();
    _port?.close();
    _port?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF141428),
        appBar: AppBar(
          title: Text(
            _isConnected
                ? 'MatrixMini Control - $_serialPort'
                : 'MatrixMini Control',
          ),
          backgroundColor: const Color(0xFF1a1a2e),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_input_composite),
              tooltip: 'Сменить порт',
              onPressed: _reconnect,
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _isConnected ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isConnected ? 'Подключено' : 'Отключено',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a1a2e),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyan.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Text(
                  'Скорость: $_speed',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00ff64),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              if (_lastKey.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.cyan, width: 2),
                  ),
                  child: Text(
                    'Команда: $_lastKey',
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.cyan,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              const SizedBox(height: 40),

              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a1a2e),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: const [
                    Text(
                      'Управление:',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text('W/A/S/D - Движение', style: TextStyle(fontSize: 16)),
                    Text('↑/↓ - Скорость ±10', style: TextStyle(fontSize: 16)),
                    Text('Пробел - Стоп', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              if (_arduinoResponse.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Arduino: $_arduinoResponse',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white60,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
