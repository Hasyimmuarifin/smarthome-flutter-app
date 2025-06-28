// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//                          Import Library
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:convert';
import 'dart:async';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//                              Variabels
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
stt.SpeechToText _speech = stt.SpeechToText();
bool _isListening = false;
String _command = '';
final player = AudioPlayer();

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//                            Fungsi main()
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void main() {
  runApp(MyApp());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//                             Class MyApp
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoT MQTT Controller',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.grey.shade800,
        ),
      ),
      home: IoTControllerPage(),
    );
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//                            Class IoTControllerPage
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class IoTControllerPage extends StatefulWidget {
  @override
  _IoTControllerPageState createState() => _IoTControllerPageState();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//                      Class _IoTControllerPageState
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
class _IoTControllerPageState extends State<IoTControllerPage> with TickerProviderStateMixin {
  MqttServerClient? client;
  bool isConnected = false;
  String connectionStatus = 'Disconnected';
  late AnimationController _pulseController;
  late AnimationController _rotateController;

  // - - - - - - - - - - - - - - MQTT Configuration - - - - - - - - - - -  - - -
  String broker = '192.168.11.103'; // Ganti dengan broker Anda
  int port = 1883;
  String clientId = 'flutter_client_${DateTime.now().millisecondsSinceEpoch}';
  String username = 'uas25_hasyim'; // MQTT Username
  String password = 'uas25_hasyim'; // MQTT Password

  // - - - - - - - - - - - - Registration Topics MQTT - - - - - - - - - - -  - -
  bool pirState = false; // Ada / tidak ada gerakan
  bool pirEnabled = true; // PIR aktif atau nonaktif (toggle)
  bool lampuState = false;
  bool kipasState = false;
  String ledTopic = 'esp32/led';
  String sensorTopic = 'esp32/sensor';
  String statusTopic = 'esp32/status';
  String lamputopic = "esp32/lampu";
  String kipastopic = "esp32/kipas";
  String listriktopic = "esp32/listrik";
  String pircontroltopic = "esp32/pir_control";
  String pirstatustopic = "esp32/pir_status";

  // - - - - - - - - - - - - - - Devices State - - - - - - - - - - - - - -  - -
  bool ledState = false;
  double temperature = 0.0;
  double humidity = 0.0;
  int fire = 0;
  int gas = 0;
  String fireStatus = 'AMAN'; // default
  String gasStatus = 'NORMAL';   // default
  String deviceStatus = 'Offline';
  int uptime = 0;

  // - - - - - -  - - - - - - - Controllers - - - - - - - - - - - - - - - - - -
  TextEditingController brokerController = TextEditingController();
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController topicController = TextEditingController();

  // - - - - - -  - - - - - - - initState() - - - - - - - - - - - - - - - - - -
  @override
  void initState() {
    super.initState();
    brokerController.text = broker;
    setupMqttClient();
    initSpeech();
    
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _rotateController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  // - - - - - -  - - - - - - - initSpeech() - - - - - - - - - - - - - - - - - -
  void initSpeech() async {
    await _speech.initialize();
  }

  void triggerFireAlarm() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 500, 1000, 500]); // getar dengan pola
    }
    player.play(AssetSource('sound/PeringatanKebakaran.mp3'));
  }

  void triggerGasAlarm() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 500, 1000, 500]); // getar dengan pola
    }
    player.play(AssetSource('sound/PeringatanKebocorangas.mp3'));
  }

  // - - - - - -  - - - - - - Setup MQTT Client() - - - - - - - - - - - - - - -
  void setupMqttClient() {
    client = MqttServerClient(broker, clientId);
    client!.port = port;
    client!.keepAlivePeriod = 30;
    client!.onDisconnected = onDisconnected;
    client!.onConnected = onConnected;
    client!.onSubscribed = onSubscribed;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withWillTopic('clients/flutter')
        .withWillMessage('Flutter client disconnected')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    // Add authentication if username and password are provided
    if (username.isNotEmpty && password.isNotEmpty) {
      connMess.authenticateAs(username, password);
    }

    client!.connectionMessage = connMess;
  }

  // - - - - - -  - - - - - - Connect to MQTT Broker() - - - - - - - - - - - - -
  Future<void> connectToMqtt() async {
    setState(() {
      connectionStatus = 'Connecting...';
    });

    // Update credentials from text fields
    broker = brokerController.text;
    username = usernameController.text;
    password = passwordController.text;

    // Recreate client with new broker address
    setupMqttClient();

    try {
      await client!.connect();
    } catch (e) {
      print('Exception: $e');
      client!.disconnect();
      setState(() {
        connectionStatus = 'Connection failed: ${e.toString()}';
        isConnected = false;
      });
    }
  }

  // - - - - - -  - - - - - - - - - onConnected() - - - - - - - - - - - - - - -
  void onConnected() {
    setState(() {
      connectionStatus = 'Connected';
      isConnected = true;
    });

    // Subscribe to sensor data
    client!.subscribe(sensorTopic, MqttQos.atMostOnce);
    client!.subscribe(statusTopic, MqttQos.atMostOnce);
    client!.subscribe(lamputopic, MqttQos.atMostOnce);
    client!.subscribe(kipastopic, MqttQos.atMostOnce);
    client!.subscribe(pircontroltopic, MqttQos.atMostOnce);
    client!.subscribe(pirstatustopic, MqttQos.atMostOnce);

    // Listen for messages
    client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final message = MqttPublishPayload.bytesToStringAsString(
        recMess.payload.message,
      );

      handleIncomingMessage(c[0].topic, message);
    });

    print('Connected to MQTT broker');
  }

  // - - - - - -  - - - - - - - - - onDisConnected() - - - - - - - - - - - - - -
  void onDisconnected() {
    setState(() {
      connectionStatus = 'Disconnected';
      isConnected = false;
      deviceStatus = 'Offline';
    });
    print('Disconnected from MQTT broker');
  }

  // - - - - - -  - - - - - - - onSubscribed() - - - - - - - - - - - - - - - - -
  void onSubscribed(String topic) {
    print('Subscribed to topic: $topic');
  }

  // - - - - - -  - - - - handle Incoming Message() - - - - - - - - - - - - - -
  void handleIncomingMessage(String topic, String message) {
    print('Received message: $message from topic: $topic');

    setState(() {
      if (topic == sensorTopic) {
        try {
          final data = json.decode(message);
          temperature = data['temperature']?.toDouble() ?? 0.0;
          humidity = data['humidity']?.toDouble() ?? 0.0;
          fire = data['flame_percent'];
          fireStatus = data['flame_status'];
          gas = data['gas_percent'];
          gasStatus = data['gas_status'];

          // Trigger alarm jika kondisi gawat
          if (fireStatus == "BAHAYA") {
            triggerFireAlarm();
          }
          if (gasStatus == "BOCOR") {
            triggerGasAlarm();
          }

          final pirValue = data['pir'] ?? "";
          if (pirValue == "Terdeteksi") {
            pirState = true;
            pirEnabled = true;
          } else if (pirValue == "Tidak Ada") {
            pirState = false;
            pirEnabled = true;
          } else if (pirValue == "PIR Nonaktif") {
            pirEnabled = false;
          }
        } catch (e) {
          print('Error parsing sensor data: $e');
        }
      } else if (topic == statusTopic) {
        try {
          final data = json.decode(message);
          deviceStatus = data['status'] ?? 'Offline';
          uptime = data['uptime']?.toInt() ?? 0;
        } catch (e) {
          print('Error parsing status data: $e');
          // Fallback to treating message as plain text
          deviceStatus = message;
        }
      } else if (topic == lamputopic) {
        try {
          final data = json.decode(message);
          lampuState = data['state'] == true;
        } catch (e) {
          print('Error parsing lampu state: $e');
        }
      } else if (topic == kipastopic) {
        try {
          final data = json.decode(message);
          kipasState = data['state'] == true;
        } catch (e) {
          print('Error parsing kipas state: $e');
        }
      } else if (topic == pircontroltopic) {
        try {
          final data = json.decode(message);
          pirState = data['enabled'] == true;
        } catch (e) {
          print('Error parsing lampu state: $e');
        }
      } else if (topic == "esp32/pir_status") {
        try {
          final data = json.decode(message);
          final status = data['status'];
          if (status == "Terdeteksi") {
            pirEnabled = true;
            pirState = true;
          } else if (status == "Tidak Ada") {
            pirEnabled = true;
            pirState = false;
          } else if (status == "PIR Nonaktif") {
            pirEnabled = false;
          }
        } catch (e) {
          print("Error parsing PIR status: $e");
        }
      }
    });
  }

  // - - - - - -  - - - - - - Publish Message() - - - - - - - - - - - - - - - -
  void publishMessage(String topic, String message) {
    if (isConnected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      client!.publishMessage(topic, MqttQos.exactlyOnce, builder.payload!);
      print('Published message: $message to topic: $topic');
    }
  }

  // - - - - - -  - - - - - - - Publish MQTT() - - - - - - - - - - - - - - - - -
  void publishMqtt(String topic, Map<String, dynamic> payload) {
    if (isConnected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(json.encode(payload));
      client!.publishMessage(topic, MqttQos.exactlyOnce, builder.payload!);
      print('Published message: $payload to topic: $topic');
    }
  }

  // - - - - - -  - - - - - - - Toogle Lampu() - - - - - - - - - - - - - - - - -
  void toggleLampu() {
    lampuState = !lampuState;
    final message = json.encode({'state': lampuState});
    publishMessage(lamputopic, message);
    setState(() {});
  }

  // - - - - - -  - - - - - - - Toogle Kipas() - - - - - - - - - - - - - - - - -
  void toggleKipas() {
    kipasState = !kipasState;
    final message = json.encode({'state': kipasState});
    publishMessage(kipastopic, message);
    setState(() {});
  }

  // Fungsi untuk toggle PIR
  void togglePIR(bool value) {
    setState(() {
      pirEnabled = value;
    });

    final data = {
      "enabled": value,
    };

    final payload = jsonEncode(data);
    final builder = MqttClientPayloadBuilder();
    builder.addUTF8String(payload);

    client?.publishMessage(
      "esp32/pir_control",
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  void toggleListrik(bool value) {
    // Setel status lampu dan kipas mengikuti status listrik
    lampuState = value;
    kipasState = value;

    // Publish ke semua topik
    publishMqtt("esp32/lampu", {"state": lampuState});
    publishMqtt("esp32/kipas", {"state": kipasState});
    publishMqtt("esp32/listrik", {"state": value});

    setState(() {}); // Update tampilan UI
  }

  // - - - - - -  - - - - - - - Disconnect() - - - - - - - - - - - - - - - - - -
  void disconnect() {
    client!.disconnect();
  }

  // - - - - - -  - - - - - - - Dispose() - - - - - - - - - - - - - - - - - - -
  @override
  void dispose() {
    client?.disconnect();
    brokerController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    topicController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  // - - - - - -  - - - - - - - - Listen Command() - - - - - - - - - - - - - - -
  void listenCommand() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() {
        _isListening = true;
      });
      _speech.listen(
        onResult: (result) {
          setState(() {
            _command = result.recognizedWords.toLowerCase();
          });
          print("Perintah suara: $_command");
          handleVoiceCommand(_command);
        },
      );
      // Stop listening after 3 seconds
      Timer(Duration(seconds: 3), () {
        if (_isListening) {
          _speech.stop();
          setState(() {
            _isListening = false;
          });
        }
      });
    } else {
      print("Speech recognition not available");
    }
  }

  // - - - - - -  - - - - - - - Handle Voice Command() - - - - - - - - - - - - -
  void handleVoiceCommand(String command) {
    if (!isConnected || client == null) {
      print("MQTT belum terhubung.");
      return;
    }

    if (command.contains("nyalakan lampu")) {
      publishMqtt("esp32/lampu", {"state": true});
    } else if (command.contains("matikan lampu")) {
      publishMqtt("esp32/lampu", {"state": false});
    } else if (command.contains("nyalakan kipas")) {
      publishMqtt("esp32/kipas", {"state": true});
    } else if (command.contains("matikan kipas")) {
      publishMqtt("esp32/kipas", {"state": false});
    } else if (command.contains("nyalakan listrik")) {
      publishMqtt("esp32/listrik", {"state": true});
      publishMqtt("esp32/lampu", {"state": true});
      publishMqtt("esp32/kipas", {"state": true});
    } else if (command.contains("matikan listrik")) {
      publishMqtt("esp32/listrik", {"state": false});
      publishMqtt("esp32/lampu", {"state": false});
      publishMqtt("esp32/kipas", {"state": false});
    } else if (command.contains("nyalakan sensor gerak") ||
        command.contains("nyalakan pir")) {
      togglePIR(true);
    } else if (command.contains("matikan sensor gerak") ||
        command.contains("matikan pir")) {
      togglePIR(false);
    } else {
      print("Perintah tidak dikenali.");
    }
  }

  // Helper method to create gradient containers
  Widget _buildGradientCard({
    required Widget child,
    required List<Color> colors,
    double? height,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // - - - - - -  - - - - - WIDGET BUILD (TAMPILAN) - - - - - - - - - - - - - -
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.developer_board, color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Text(
              'IoT Controller',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Section with Modern Design
            _buildGradientCard(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.wifi, color: Colors.white, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'MQTT Connection',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: brokerController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'MQTT Broker',
                          labelStyle: TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          prefixIcon: Icon(Icons.dns, color: Colors.white70),
                        ),
                        onChanged: (value) => broker = value,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: usernameController,
                              style: TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Username',
                                labelStyle: TextStyle(color: Colors.white70),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.1),
                                prefixIcon: Icon(Icons.person, color: Colors.white70),
                              ),
                              onChanged: (value) => username = value,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: passwordController,
                              style: TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle: TextStyle(color: Colors.white70),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.1),
                                prefixIcon: Icon(Icons.lock, color: Colors.white70),
                              ),
                              obscureText: true,
                              onChanged: (value) => password = value,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isConnected ? null : connectToMqtt,
                            icon: Icon(Icons.link),
                            label: Text('Connect'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Color(0xFF6366F1),
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isConnected ? disconnect : null,
                            icon: Icon(Icons.link_off),
                            label: Text('Disconnect'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade400,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: isConnected ? Colors.green : Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (isConnected ? Colors.green : Colors.red)
                                        .withOpacity(_pulseController.value),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        SizedBox(width: 8),
                        Text(
                          connectionStatus,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Device Status with animated indicator
            Card(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.devices, color: Color(0xFF6366F1), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Device Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: deviceStatus.toLowerCase() == 'online'
                                    ? Colors.green
                                    : Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (deviceStatus.toLowerCase() == 'online'
                                            ? Colors.green
                                            : Colors.red)
                                        .withOpacity(_pulseController.value),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        SizedBox(width: 12),
                        Text(
                          deviceStatus,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: deviceStatus.toLowerCase() == 'online'
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        Spacer(),
                        if (uptime > 0)
                          Text(
                            'Uptime: ${uptime}s',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Voice Control Section
            _buildGradientCard(
              colors: [Color(0xFF10B981), Color(0xFF34D399)],
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.mic, color: Colors.white, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Voice Control',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return GestureDetector(
                          onTap: listenCommand,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(
                                    _isListening ? _pulseController.value : 0.3,
                                  ),
                                  blurRadius: 20,
                                  spreadRadius: _isListening ? 10 : 0,
                                ),
                              ],
                            ),
                            child: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              size: 40,
                              color: _isListening ? Color(0xFF10B981) : Color(0xFF6B7280),
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 12),
                    Text(
                      _isListening ? 'Listening...' : 'Tap to speak',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_command.isNotEmpty)
                      Container(
                        margin: EdgeInsets.only(top: 12),
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Command: $_command',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Controls Section
            Card(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.control_camera, color: Color(0xFF6366F1), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Device Controls',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    
                    // Main Power Control
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.power_settings_new, color: Colors.white, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Main Power',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Controls all devices',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: lampuState && kipasState,
                            onChanged: toggleListrik,
                            activeColor: Colors.white,
                            activeTrackColor: Colors.white.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Individual Controls
                    Row(
                      children: [
                        Expanded(
                          child: _buildControlCard(
                            icon: Icons.lightbulb,
                            title: 'Lampu',
                            subtitle: lampuState ? 'ON' : 'OFF',
                            isActive: lampuState,
                            onTap: toggleLampu,
                            colors: [Color(0xFFF59E0B), Color(0xFFEAB308)],
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildControlCard(
                            icon: Icons.air,
                            title: 'Kipas',
                            subtitle: kipasState ? 'ON' : 'OFF',
                            isActive: kipasState,
                            onTap: toggleKipas,
                            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // PIR Control
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: pirEnabled ? Color(0xFF10B981) : Colors.grey,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.motion_photos_on,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Motion Sensor (PIR)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  pirEnabled 
                                    ? (pirState ? 'Motion Detected' : 'No Motion')
                                    : 'Disabled',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: pirEnabled,
                            onChanged: togglePIR,
                            activeColor: Color(0xFF10B981),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Sensor Data Section
            Card(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.sensors, color: Color(0xFF6366F1), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Sensor Data',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    
                    // Temperature & Humidity
                    Row(
                      children: [
                        Expanded(
                          child: _buildSensorCard(
                            icon: Icons.thermostat,
                            title: 'Temperature',
                            value: '${temperature.toStringAsFixed(1)}°C',
                            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildSensorCard(
                            icon: Icons.water_drop,
                            title: 'Humidity',
                            value: '${humidity.toStringAsFixed(1)}%',
                            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 12),
                    
                    // Fire & Gas Detection
                    Row(
                      children: [
                        Expanded(
                          child: _buildSensorCard(
                            icon: Icons.local_fire_department,
                            title: 'Fire Detection',
                            value: '$fire%',
                            subtitle: fireStatus,
                            colors: fireStatus == 'BAHAYA' 
                              ? [Color(0xFFDC2626), Color(0xFFB91C1C)]
                              : [Color(0xFF059669), Color(0xFF047857)],
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildSensorCard(
                            icon: Icons.cloud,
                            title: 'Gas Detection',
                            value: '$gas%',
                            subtitle: gasStatus,
                            colors: gasStatus == 'BOCOR' 
                              ? [Color(0xFFDC2626), Color(0xFFB91C1C)]
                              : [Color(0xFF059669), Color(0xFF047857)],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Helper method to build control cards
  Widget _buildControlCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required VoidCallback onTap,
    required List<Color> colors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isActive 
            ? LinearGradient(colors: colors)
            : LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade400]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: (isActive ? colors.first : Colors.grey).withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: Colors.white,
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build sensor cards
  Widget _buildSensorCard({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
    required List<Color> colors,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}