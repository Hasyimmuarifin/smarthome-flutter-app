import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:convert';
import 'dart:async';

stt.SpeechToText _speech = stt.SpeechToText();
bool _isListening = false;
String _command = '';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoT MQTT Controller',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: IoTControllerPage(),
    );
  }
}

class IoTControllerPage extends StatefulWidget {
  @override
  _IoTControllerPageState createState() => _IoTControllerPageState();
}

class _IoTControllerPageState extends State<IoTControllerPage> {
  MqttServerClient? client;
  bool isConnected = false;
  String connectionStatus = 'Disconnected';

  // MQTT Configuration
  String broker = '192.168.236.245'; // Ganti dengan broker Anda
  int port = 1883;
  String clientId = 'flutter_client_${DateTime.now().millisecondsSinceEpoch}';
  String username = 'budi'; // MQTT Username
  String password = 'budi123'; // MQTT Password

  // Topics
  String ledTopic = 'esp32/led';
  String sensorTopic = 'esp32/sensor';
  String statusTopic = 'esp32/status';

  // Device States
  bool ledState = false;
  double temperature = 0.0;
  double humidity = 0.0;
  String deviceStatus = 'Offline';
  int uptime = 0;

  // Controllers
  TextEditingController brokerController = TextEditingController();
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController topicController = TextEditingController();

  @override
  void initState() {
    super.initState();
    brokerController.text = broker;
    setupMqttClient();
    initSpeech();
  }

  void initSpeech() async {
    await _speech.initialize();
  }

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

  void onConnected() {
    setState(() {
      connectionStatus = 'Connected';
      isConnected = true;
    });

    // Subscribe to sensor data
    client!.subscribe(sensorTopic, MqttQos.atMostOnce);
    client!.subscribe(statusTopic, MqttQos.atMostOnce);

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

  void onDisconnected() {
    setState(() {
      connectionStatus = 'Disconnected';
      isConnected = false;
      deviceStatus = 'Offline';
    });
    print('Disconnected from MQTT broker');
  }

  void onSubscribed(String topic) {
    print('Subscribed to topic: $topic');
  }

  void handleIncomingMessage(String topic, String message) {
    print('Received message: $message from topic: $topic');

    setState(() {
      if (topic == sensorTopic) {
        try {
          final data = json.decode(message);
          temperature = data['temperature']?.toDouble() ?? 0.0;
          humidity = data['humidity']?.toDouble() ?? 0.0;
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
      }
    });
  }

  void publishMessage(String topic, String message) {
    if (isConnected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      client!.publishMessage(topic, MqttQos.exactlyOnce, builder.payload!);
      print('Published message: $message to topic: $topic');
    }
  }

  void publishMqtt(String topic, Map<String, dynamic> payload) {
    if (isConnected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(json.encode(payload));
      client!.publishMessage(topic, MqttQos.exactlyOnce, builder.payload!);
      print('Published message: $payload to topic: $topic');
    }
  }

  void toggleLED() {
    ledState = !ledState;
    final message = json.encode({'led': ledState});
    publishMessage(ledTopic, message);
    setState(() {});
  }

  void disconnect() {
    client!.disconnect();
  }

  @override
  void dispose() {
    client?.disconnect();
    brokerController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    topicController.dispose();
    super.dispose();
  }

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
    } else {
      print("Speech recognition not available");
    }
  }

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
      publishMqtt("esp32/listrik", {"lampu": true, "kipas": true});
    } else if (command.contains("matikan listrik")) {
      publishMqtt("esp32/listrik", {"lampu": false, "kipas": false});
    } else {
      print("Perintah tidak dikenali.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('IoT MQTT Controller'),
        backgroundColor: Colors.blue[700],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Section
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MQTT Connection',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: brokerController,
                      decoration: InputDecoration(
                        labelText: 'MQTT Broker',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.dns),
                      ),
                      onChanged: (value) => broker = value,
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: usernameController,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            onChanged: (value) => username = value,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: passwordController,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock),
                            ),
                            obscureText: true,
                            onChanged: (value) => password = value,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isConnected ? null : connectToMqtt,
                            child: Text('Connect'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isConnected ? disconnect : null,
                            child: Text('Disconnect'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Status: $connectionStatus',
                      style: TextStyle(
                        color: isConnected ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Device Status
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          color: deviceStatus.toLowerCase() == 'online'
                              ? Colors.green
                              : Colors.red,
                          size: 12,
                        ),
                        SizedBox(width: 8),
                        Text(
                          deviceStatus.toUpperCase(),
                          style: TextStyle(
                            color: deviceStatus.toLowerCase() == 'online'
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (uptime > 0) ...[
                          SizedBox(width: 15),
                          Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                          SizedBox(width: 5),
                          Text(
                            'Uptime: ${_formatUptime(uptime)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Control Section
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device Control',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 15),
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb,
                          color: ledState ? Colors.yellow : Colors.grey,
                          size: 30,
                        ),
                        SizedBox(width: 15),
                        Text(
                          'LED: ${ledState ? "ON" : "OFF"}',
                          style: TextStyle(fontSize: 16),
                        ),
                        Spacer(),
                        Switch(
                          value: ledState,
                          onChanged:
                              isConnected ? (value) => toggleLED() : null,
                          activeColor: Colors.blue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Sensor Data Section
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sensor Data',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Icon(
                                Icons.thermostat,
                                size: 30,
                                color: Colors.red,
                              ),
                              SizedBox(height: 5),
                              Text(
                                '${temperature.toStringAsFixed(1)}°C',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('Temperature'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Icon(
                                Icons.water_drop,
                                size: 30,
                                color: Colors.blue,
                              ),
                              SizedBox(height: 5),
                              Text(
                                '${humidity.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('Humidity'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20), // Add some bottom padding
            // IconButton(
            //   icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
            //   onPressed: listenCommand,
            // )
            ElevatedButton.icon(
              onPressed: listenCommand,
              icon: Icon(Icons.mic),
              label: Text(_isListening ? 'Mendengarkan...' : 'Mulai Suara'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
