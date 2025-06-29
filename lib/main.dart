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
      title: 'Smart Home Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: Color(0xFF1E3A8A),
        scaffoldBackgroundColor: Color(0xFFF8FAFC),
        cardTheme: CardTheme(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF1E3A8A),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFF1E3A8A), width: 2),
          ),
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
class _IoTControllerPageState extends State<IoTControllerPage> {
  MqttServerClient? client;
  bool isConnected = false;
  String connectionStatus = 'Disconnected';

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

  // - - - - - -  - - - - - WIDGET BUILD (TAMPILAN) - - - - - - - - - - - - - -
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Smart Home Controller'),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isConnected ? Icons.wifi : Icons.wifi_off,
                  color: isConnected ? Colors.greenAccent : Colors.redAccent,
                  size: 20,
                ),
                SizedBox(width: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: deviceStatus.toLowerCase() == 'online' 
                        ? Colors.green 
                        : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: ClampingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.all(12.0),
            child: Column(
              children: [
            // Connection Section
            _buildConnectionCard(),
            SizedBox(height: 12),
            
            // Device Status
            _buildDeviceStatusCard(),
            SizedBox(height: 12),
            
            // Control Sections in Grid
            _buildControlGrid(),
            SizedBox(height: 12),
            
            // Sensor Data
            _buildSensorDataCard(),
            SizedBox(height: 12),
            
            // Fire and Gas Section
            _buildFireGasCard(),
            SizedBox(height: 12),
            
            // Voice Command Button
            _buildVoiceCommandButton(),
            SizedBox(height: 20),
          ],
        ),
      ),
      ),
      ),
    );
  }

  // Helper methods for building UI components
  Widget _buildConnectionCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_sync, color: Theme.of(context).primaryColor),
                SizedBox(width: 8),
                Text(
                  'MQTT Connection',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                Spacer(),
                _buildConnectionStatusChip(),
              ],
            ),
            SizedBox(height: 16),
            TextField(
              controller: brokerController,
              decoration: InputDecoration(
                labelText: 'MQTT Broker',
                prefixIcon: Icon(Icons.dns),
                isDense: true,
              ),
              onChanged: (value) => broker = value,
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person),
                      isDense: true,
                    ),
                    onChanged: (value) => username = value,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock),
                      isDense: true,
                    ),
                    obscureText: true,
                    onChanged: (value) => password = value,
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
                    icon: Icon(Icons.link, size: 18),
                    label: Text('Connect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isConnected ? disconnect : null,
                    icon: Icon(Icons.link_off, size: 18),
                    label: Text('Disconnect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusChip() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.check_circle : Icons.error,
            size: 14,
            color: isConnected ? Colors.green.shade700 : Colors.red.shade700,
          ),
          SizedBox(width: 4),
          Text(
            connectionStatus,
            style: TextStyle(
              color: isConnected ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceStatusCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.devices_other, color: Theme.of(context).primaryColor),
                SizedBox(width: 8),
                Text(
                  'Device Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: deviceStatus.toLowerCase() == 'online'
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    deviceStatus.toLowerCase() == 'online'
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    color: deviceStatus.toLowerCase() == 'online'
                        ? Colors.green.shade600
                        : Colors.red.shade600,
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceStatus.toUpperCase(),
                        style: TextStyle(
                          color: deviceStatus.toLowerCase() == 'online'
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (uptime > 0)
                        Text(
                          'Uptime: ${_formatUptime(uptime)}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildLampuControl()),
            SizedBox(width: 8),
            Expanded(child: _buildKipasControl()),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildListrikControl()),
            SizedBox(width: 8),
            Expanded(child: _buildPirControl()),
          ],
        ),
      ],
    );
  }

  Widget _buildLampuControl() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(
              Icons.lightbulb,
              size: 32,
              color: lampuState ? Colors.amber.shade600 : Colors.grey.shade400,
            ),
            SizedBox(height: 8),
            Text(
              'Lampu',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              lampuState ? 'ON' : 'OFF',
              style: TextStyle(
                color: lampuState ? Colors.amber.shade700 : Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: lampuState,
                onChanged: isConnected ? (value) => toggleLampu() : null,
                activeColor: Colors.amber.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKipasControl() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(
              Icons.air,
              size: 32,
              color: kipasState ? Colors.blue.shade600 : Colors.grey.shade400,
            ),
            SizedBox(height: 8),
            Text(
              'Kipas',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              kipasState ? 'ON' : 'OFF',
              style: TextStyle(
                color: kipasState ? Colors.blue.shade700 : Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: kipasState,
                onChanged: isConnected ? (value) => toggleKipas() : null,
                activeColor: Colors.blue.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListrikControl() {
    bool isOn = lampuState || kipasState;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(
              Icons.power,
              size: 32,
              color: isOn ? Colors.green.shade600 : Colors.grey.shade400,
            ),
            SizedBox(height: 8),
            Text(
              'Listrik',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              isOn ? 'ON' : 'OFF',
              style: TextStyle(
                color: isOn ? Colors.green.shade700 : Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: isOn,
                onChanged: isConnected ? (value) => toggleListrik(value) : null,
                activeColor: Colors.green.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPirControl() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(
              pirEnabled
                  ? (pirState ? Icons.directions_run : Icons.accessibility_new)
                  : Icons.do_not_touch,
              size: 32,
              color: pirEnabled
                  ? (pirState ? Colors.orange.shade600 : Colors.blue.shade600)
                  : Colors.grey.shade400,
            ),
            SizedBox(height: 8),
            Text(
              'PIR',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              pirEnabled ? (pirState ? 'DETECT' : 'CLEAR') : 'OFF',
              style: TextStyle(
                color: pirEnabled
                    ? (pirState ? Colors.orange.shade700 : Colors.blue.shade700)
                    : Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: pirEnabled,
                onChanged: isConnected ? (value) => togglePIR(value) : null,
                activeColor: Colors.blue.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorDataCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sensors, color: Theme.of(context).primaryColor),
                SizedBox(width: 8),
                Text(
                  'Sensor Data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTemperatureWidget()),
                SizedBox(width: 12),
                Expanded(child: _buildHumidityWidget()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemperatureWidget() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.thermostat, size: 32, color: Colors.red.shade600),
          SizedBox(height: 8),
          Text(
            '${temperature.toStringAsFixed(1)}°C',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          Text(
            'Temperature',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHumidityWidget() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.water_drop, size: 32, color: Colors.blue.shade600),
          SizedBox(height: 8),
          Text(
            '${humidity.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          Text(
            'Humidity',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFireGasCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Theme.of(context).primaryColor),
                SizedBox(width: 8),
                Text(
                  'Fire & Gas Monitor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildFireWidget()),
                SizedBox(width: 12),
                Expanded(child: _buildGasWidget()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFireWidget() {
    MaterialColor statusColorMaterial;
    String statusText = fireStatus;
    
    if (fireStatus == "BAHAYA") {
      statusColorMaterial = Colors.red;
    } else if (fireStatus == "WASPADA") {
      statusColorMaterial = Colors.orange;
    } else {
      statusColorMaterial = Colors.green;
    }
        
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColorMaterial.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColorMaterial.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.local_fire_department, size: 32, color: statusColorMaterial.shade600),
          SizedBox(height: 8),
          Text(
            '${fire.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: statusColorMaterial.shade700,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColorMaterial.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: statusColorMaterial.shade800,
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Fire',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGasWidget() {
    MaterialColor statusColorMaterial = gasStatus == "BOCOR" ? Colors.red : Colors.green;
        
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColorMaterial.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColorMaterial.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.gas_meter, size: 32, color: statusColorMaterial.shade600),
          SizedBox(height: 8),
          Text(
            '${gas.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: statusColorMaterial.shade700,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColorMaterial.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              gasStatus,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: statusColorMaterial.shade800,
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Gas',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceCommandButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: listenCommand,
        icon: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isListening ? Colors.red.withOpacity(0.2) : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isListening ? Icons.mic : Icons.mic_none,
            color: _isListening ? Colors.red : Colors.white,
            size: 24,
          ),
        ),
        label: Text(
          _isListening ? 'Mendengarkan...' : 'Perintah Suara',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isListening ? Colors.orange.shade200 : Colors.orange.shade600,
          foregroundColor: _isListening ? Colors.orange.shade900 : Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: _isListening ? 1 : 3,
        ),
      ),
    );
  }

  // - - - - - -  - - - - - - - - - Format Up Time() - - - - - - - - - - - - - -
  String _formatUptime(int seconds) {
    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    final int secs = seconds % 60;
    return '${hours}h ${minutes}m ${secs}s';

    // if (hours > 0) {
    //   return '${hours}h ${minutes}m ${secs}s';
    // } else if (minutes > 0) {
    //   return '${minutes}m ${secs}s';
    // } else {
    //   return '${secs}s';
    // }
  }
}