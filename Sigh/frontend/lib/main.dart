/* import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: VideoStreamPage(),
    );
  }
}

class VideoStreamPage extends StatefulWidget {
  const VideoStreamPage({super.key});

  @override
  State<VideoStreamPage> createState() => _VideoStreamPageState();
}

class _VideoStreamPageState extends State<VideoStreamPage> {
  WebSocketChannel? channel;
  Uint8List? latestFrame;
  bool isStreaming = false;

  void startStream() {
  print('🔄 Attempting to connect to WebSocket...');
  
  channel = WebSocketChannel.connect(
    Uri.parse('ws://127.0.0.1:8080/ws/stream/'),
  );

  channel!.stream.listen(
    (event) {
      //print('📨 Received data type: ${event.runtimeType}');
      //print('📨 Data length: ${event.length}');
      
      if (event is Uint8List) {
        //print('✅ Valid Uint8List received, updating frame');
        setState(() {
          latestFrame = event;
        });
      } else {
        print('❌ Unexpected data type: $event');
      }
    },
    onError: (error) {
      print('❌ WebSocket error: $error');
    },
    onDone: () {
      print('🔌 WebSocket connection closed');
    },
  );

  setState(() => isStreaming = true);
  print('✅ WebSocket connection established');
  }

  void stopStream() {
    channel?.sink.close();
    setState(() {
      isStreaming = false;
      latestFrame = null;
    });
  }

  @override
  void dispose() {
    channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Real-Time Face Recognition')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: latestFrame == null
                  ? const Text('Waiting for video stream...')
                  : Image.memory(
                      latestFrame!,
                      gaplessPlayback: true,
                      fit: BoxFit.contain,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: isStreaming ? null : startStream,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Stream'),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: isStreaming ? stopStream : null,
                icon: const Icon(Icons.stop),
                label: const Text('Stop Stream'),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
 */
/* import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: VideoStreamPage(),
    );
  }
}

class VideoStreamPage extends StatefulWidget {
  const VideoStreamPage({super.key});

  @override
  State<VideoStreamPage> createState() => _VideoStreamPageState();
}

class _VideoStreamPageState extends State<VideoStreamPage> {
  WebSocketChannel? channel;
  Uint8List? latestFrame;
  bool isStreaming = false;
  bool showRegistrationDialog = false;
  String? currentUnknownFaceImage;

  // Registration form controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController roleController = TextEditingController();

  void startStream() {
    print('🔄 Attempting to connect to WebSocket...');
    
    channel = WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:8080/ws/stream/'),
    );

    channel!.stream.listen(
      (event) {
        if (event is Uint8List) {
          setState(() {
            latestFrame = event;
          });
        } else if (event is String) {
          // Handle text messages (like registration results)
          handleTextMessage(event);
        }
      },
      onError: (error) {
        print('❌ WebSocket error: $error');
      },
      onDone: () {
        print('🔌 WebSocket connection closed');
      },
    );

    setState(() => isStreaming = true);
    print('✅ WebSocket connection established');
  }

  void handleTextMessage(String message) {
    try {
      final data = json.decode(message);
      if (data['type'] == 'registration_result') {
        if (data['success'] == true) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Success'),
              content: Text('Face registered successfully for ${data['name']}'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      showRegistrationDialog = false;
                    });
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (context) => const AlertDialog(
              title: Text('Error'),
              content: Text('Failed to register face. Please try again.'),
              actions: [
                TextButton(
                  onPressed: null,
                  child: Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print('Error parsing message: $e');
    }
  }

  void stopStream() {
    channel?.sink.close();
    setState(() {
      isStreaming = false;
      latestFrame = null;
    });
  }

  void captureAndRegisterFace() {
    if (latestFrame == null) return;

    // Convert current frame to base64 for sending
    final base64Image = base64Encode(latestFrame!);
    
    setState(() {
      currentUnknownFaceImage = base64Image;
      showRegistrationDialog = true;
    });
  }

  void submitRegistration() {
    final name = nameController.text.trim();
    final role = roleController.text.trim();

    if (name.isEmpty || role.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Please enter both name and role'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Send registration request to server
    final registrationData = {
      'type': 'register_face',
      'face_data': currentUnknownFaceImage,
      'name': name,
      'role': role,
    };

    channel?.sink.add(json.encode(registrationData));

    // Clear form
    nameController.clear();
    roleController.clear();
  }

  void cancelRegistration() {
    setState(() {
      showRegistrationDialog = false;
      nameController.clear();
      roleController.clear();
    });
  }

  @override
  void dispose() {
    channel?.sink.close();
    nameController.dispose();
    roleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-Time Face Recognition'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: latestFrame == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam_off, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Waiting for video stream...'),
                          ],
                        )
                      : Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Image.memory(
                              latestFrame!,
                              gaplessPlayback: true,
                              fit: BoxFit.contain,
                            ),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              color: Colors.black54,
                              child: const Text(
                                'Face detected: Unknown - Click "Register Face" to add',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: isStreaming ? null : startStream,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Stream'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: isStreaming ? stopStream : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Stream'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: isStreaming && latestFrame != null 
                        ? captureAndRegisterFace 
                        : null,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Register Face'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),

          // Registration Dialog
          if (showRegistrationDialog)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Register New Face',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (currentUnknownFaceImage != null)
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Image.memory(
                            base64Decode(currentUnknownFaceImage!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: roleController,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ElevatedButton(
                            onPressed: cancelRegistration,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: submitRegistration,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Register'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} */
/* 
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'screens/management_main_screen.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'services/api_service.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<ApiService>(
       create: (_) => ApiService(http.Client()),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const VideoStreamPage(),
      ),
    );
  }
}

class VideoStreamPage extends StatefulWidget {
  const VideoStreamPage({super.key});

  @override
  State<VideoStreamPage> createState() => _VideoStreamPageState();
}

class _VideoStreamPageState extends State<VideoStreamPage> {
  WebSocketChannel? channel;
  Uint8List? latestFrame;
  bool isStreaming = false;
  bool showRegistrationDialog = false;
  bool showSessionDialog = false;
  bool showParticipantsDialog = false;
  String? currentUnknownFaceImage;

  // Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController roleController = TextEditingController();
  final TextEditingController sessionNameController = TextEditingController();
  final TextEditingController sessionDescController = TextEditingController();

  // Session data
  List<dynamic> sessions = [];
  List<dynamic> currentParticipants = [];
  String? currentSessionId;
  String? currentSessionName;

  @override
  void initState() {
    super.initState();
  }

  void startStream() {
    print('🔄 Attempting to connect to WebSocket...');
    
    channel = WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:8000/ws/stream/'),
    );

    channel!.stream.listen(
      (event) {
        if (event is Uint8List) {
          setState(() {
            latestFrame = event;
          });
        } else if (event is String) {
          handleTextMessage(event);
        }
      },
      onError: (error) {
        print('❌ WebSocket error: $error');
        showSnackBar('Connection error: $error');
      },
      onDone: () {
        print('🔌 WebSocket connection closed');
        setState(() {
          isStreaming = false;
        });
      },
    );

    setState(() => isStreaming = true);
    print('✅ WebSocket connection established');
  }

  void handleTextMessage(String message) {
    try {
      final data = json.decode(message);
      final type = data['type'];
      
      switch (type) {
        case 'registration_result':
          handleRegistrationResult(data);
          break;
        case 'session_set_result':
          handleSessionSetResult(data);
          break;
        case 'sessions_list':
          handleSessionsList(data);
          break;
        case 'session_participants':
          handleSessionParticipants(data);
          break;
        case 'error':
          showSnackBar('Error: ${data['message']}');
          break;
      }
    } catch (e) {
      print('Error parsing message: $e');
    }
  }

  void handleRegistrationResult(Map<String, dynamic> data) {
    if (data['success'] == true) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Success'),
          content: Text('Face registered successfully for ${data['name']}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  showRegistrationDialog = false;
                });
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text(data['message'] ?? 'Failed to register face'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void handleSessionSetResult(Map<String, dynamic> data) {
    if (data['success'] == true) {
      setState(() {
        currentSessionId = data['session_id'];
        // Find session name
        for (var session in sessions) {
          if (session['id'] == currentSessionId) {
            currentSessionName = session['name'];
            break;
          }
        }
      });
      showSnackBar('Session set to: $currentSessionName');
    } else {
      showSnackBar('Failed to set session: ${data['message']}');
    }
  }

  void handleSessionsList(Map<String, dynamic> data) {
    setState(() {
      sessions = data['sessions'];
    });
  }

  void handleSessionParticipants(Map<String, dynamic> data) {
    setState(() {
      currentParticipants = data['participants'];
      showParticipantsDialog = true;
    });
  }

  void stopStream() {
    channel?.sink.close();
    setState(() {
      isStreaming = false;
      latestFrame = null;
    });
  }

  void captureAndRegisterFace() {
    if (latestFrame == null) return;

    final base64Image = base64Encode(latestFrame!);
    
    setState(() {
      currentUnknownFaceImage = base64Image;
      showRegistrationDialog = true;
    });
  }

  void submitRegistration() {
    final name = nameController.text.trim();
    final role = roleController.text.trim();

    if (name.isEmpty || role.isEmpty) {
      showSnackBar('Please enter both name and role');
      return;
    }

    final registrationData = {
      'type': 'register_face',
      'face_data': currentUnknownFaceImage,
      'name': name,
      'role': role,
    };

    channel?.sink.add(json.encode(registrationData));
    nameController.clear();
    roleController.clear();
  }

  void getSessions() {
    final message = {'type': 'get_sessions'};
    channel?.sink.add(json.encode(message));
    setState(() {
      showSessionDialog = true;
    });
  }

  void setSession(String sessionId) {
    final message = {
      'type': 'set_session',
      'session_id': sessionId,
    };
    channel?.sink.add(json.encode(message));
    setState(() {
      showSessionDialog = false;
    });
  }

  void getSessionParticipants(String sessionId) {
    final message = {
      'type': 'get_session_participants',
      'session_id': sessionId,
    };
    channel?.sink.add(json.encode(message));
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildSessionInfo() {
    if (currentSessionName == null) {
      return const ListTile(
        leading: Icon(Icons.warning, color: Colors.orange),
        title: Text('No Session Selected'),
        subtitle: Text('Please select a session to track attendance'),
      );
    }

    final presentCount = currentParticipants.where((p) => p['is_present'] == true).length;
    final totalCount = currentParticipants.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentSessionName!,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Attendance: $presentCount/$totalCount present',
              style: TextStyle(
                color: presentCount == totalCount ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => getSessionParticipants(currentSessionId!),
              child: const Text('View Participants'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    channel?.sink.close();
    nameController.dispose();
    roleController.dispose();
    sessionNameController.dispose();
    sessionDescController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Recognition Attendance'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (currentSessionName != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Chip(
                label: Text(
                  currentSessionName!,
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.green,
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Session Info
              _buildSessionInfo(),

              // Video Stream
              Expanded(
                child: Center(
                  child: latestFrame == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam_off, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Waiting for video stream...'),
                          ],
                        )
                      : Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Image.memory(
                              latestFrame!,
                              gaplessPlayback: true,
                              fit: BoxFit.contain,
                            ),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              color: Colors.black54,
                              child: Text(
                                currentSessionName != null 
                                    ? 'Tracking attendance for: $currentSessionName'
                                    : 'Face detected - Select a session to track attendance',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // Control Buttons
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    // Start/Stop Stream
                    ElevatedButton.icon(
                      onPressed: isStreaming ? null : startStream,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Stream'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: isStreaming ? stopStream : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop Stream'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
// In your Control Buttons section, add this button:
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to management system
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ManagementMainScreen()),
                    );
                  },
                  icon: const Icon(Icons.manage_accounts),
                  label: const Text('Manage'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
                    // Register Face
                    ElevatedButton.icon(
                      onPressed: isStreaming && latestFrame != null 
                          ? captureAndRegisterFace 
                          : null,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Register Face'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),

                    // Session Management
                    ElevatedButton.icon(
                      onPressed: isStreaming ? getSessions : null,
                      icon: const Icon(Icons.event),
                      label: const Text('Sessions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Registration Dialog
          if (showRegistrationDialog)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Register New Face',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (currentUnknownFaceImage != null)
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Image.memory(
                              base64Decode(currentUnknownFaceImage!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: roleController,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.work),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  showRegistrationDialog = false;
                                  nameController.clear();
                                  roleController.clear();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: submitRegistration,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Register'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Sessions Dialog
          if (showSessionDialog)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: MediaQuery.of(context).size.height * 0.7,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Select Session',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: sessions.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.event_busy, size: 64, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text('No sessions available'),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: sessions.length,
                                itemBuilder: (context, index) {
                                  final session = sessions[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    child: ListTile(
                                      leading: const Icon(Icons.event, color: Colors.blue),
                                      title: Text(session['name']),
                                      subtitle: Text(session['description'] ?? 'No description'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.people, color: Colors.green),
                                            onPressed: () => getSessionParticipants(session['id']),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.check, color: Colors.blue),
                                            onPressed: () => setSession(session['id']),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            showSessionDialog = false;
                          });
                        },
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Participants Dialog
          if (showParticipantsDialog)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: MediaQuery.of(context).size.height * 0.7,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Session Participants',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: currentParticipants.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.people_outline, size: 64, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text('No participants in this session'),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: currentParticipants.length,
                                itemBuilder: (context, index) {
                                  final participant = currentParticipants[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    color: participant['is_present'] == true 
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.grey.withOpacity(0.1),
                                    child: ListTile(
                                      leading: Icon(
                                        participant['is_present'] == true 
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        color: participant['is_present'] == true 
                                            ? Colors.green
                                            : Colors.grey,
                                      ),
                                      title: Text(participant['name']),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(participant['role']),
                                          if (participant['last_seen'] != null)
                                            Text(
                                              'Last seen: ${DateTime.parse(participant['last_seen']).toString().split('.')[0]}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                        ],
                                      ),
                                      trailing: Chip(
                                        label: Text(
                                          participant['is_present'] == true ? 'Present' : 'Absent',
                                          style: TextStyle(
                                            color: participant['is_present'] == true 
                                                ? Colors.white 
                                                : Colors.black,
                                          ),
                                        ),
                                        backgroundColor: participant['is_present'] == true 
                                            ? Colors.green 
                                            : Colors.grey[300],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            showParticipantsDialog = false;
                          });
                        },
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} */
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'screens/management_main_screen.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'services/api_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<ApiService>(
      create: (_) => ApiService(http.Client()),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const VideoStreamPage(),
      ),
    );
  }
}

class VideoStreamPage extends StatefulWidget {
  const VideoStreamPage({super.key});

  @override
  State<VideoStreamPage> createState() => _VideoStreamPageState();
}

class _VideoStreamPageState extends State<VideoStreamPage> {
  WebSocketChannel? channel;
  Uint8List? latestFrame;
  bool isStreaming = false;
  bool showRegistrationDialog = false;
  bool showSessionDialog = false;
  bool showParticipantsDialog = false;
  String? currentUnknownFaceImage;

  // Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController roleController = TextEditingController();
  final TextEditingController sessionNameController = TextEditingController();
  final TextEditingController sessionDescController = TextEditingController();

  // Session data
  List<dynamic> sessions = [];
  List<dynamic> currentParticipants = [];
  String? currentSessionId;
  String? currentSessionName;

  @override
  void initState() {
    super.initState();
  }

  void startStream() {
    print('🔄 Attempting to connect to WebSocket...');

    channel = WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:8000/ws/stream/'),
    );

    channel!.stream.listen(
      (event) {
        if (event is Uint8List) {
          setState(() {
            latestFrame = event;
          });
        } else if (event is String) {
          handleTextMessage(event);
        }
      },
      onError: (error) {
        print('❌ WebSocket error: $error');
        showSnackBar('Connection error: $error');
      },
      onDone: () {
        print('🔌 WebSocket connection closed');
        setState(() {
          isStreaming = false;
        });
      },
    );

    setState(() => isStreaming = true);
    print('✅ WebSocket connection established');
  }

  void handleTextMessage(String message) {
    try {
      final data = json.decode(message);
      final type = data['type'];

      switch (type) {
        case 'registration_result':
          handleRegistrationResult(data);
          break;
        case 'session_set_result':
          handleSessionSetResult(data);
          break;
        case 'sessions_list':
          handleSessionsList(data);
          break;
        case 'session_participants':
          handleSessionParticipants(data);
          break;
        case 'error':
          showSnackBar('Error: ${data['message']}');
          break;
      }
    } catch (e) {
      print('Error parsing message: $e');
    }
  }

  void handleRegistrationResult(Map<String, dynamic> data) {
    if (data['success'] == true) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: const Text('Success'),
          content: Text('Face registered successfully for ${data['name']}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  showRegistrationDialog = false;
                });
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: const Text('Error'),
          content: Text(data['message'] ?? 'Failed to register face'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void handleSessionSetResult(Map<String, dynamic> data) {
    if (data['success'] == true) {
      setState(() {
        currentSessionId = data['session_id'];
        // Find session name
        for (var session in sessions) {
          if (session['id'] == currentSessionId) {
            currentSessionName = session['name'];
            break;
          }
        }
      });
      showSnackBar('Session set to: $currentSessionName');
    } else {
      showSnackBar('Failed to set session: ${data['message']}');
    }
  }

  void handleSessionsList(Map<String, dynamic> data) {
    setState(() {
      sessions = data['sessions'];
    });
  }

  void handleSessionParticipants(Map<String, dynamic> data) {
    setState(() {
      currentParticipants = data['participants'];
      showParticipantsDialog = true;
    });
  }

  void stopStream() {
    channel?.sink.close();
    setState(() {
      isStreaming = false;
      latestFrame = null;
    });
  }

  void captureAndRegisterFace() {
    if (latestFrame == null) return;

    final base64Image = base64Encode(latestFrame!);

    setState(() {
      currentUnknownFaceImage = base64Image;
      showRegistrationDialog = true;
    });
  }

  void submitRegistration() {
    final name = nameController.text.trim();
    final role = roleController.text.trim();

    if (name.isEmpty || role.isEmpty) {
      showSnackBar('Please enter both name and role');
      return;
    }

    final registrationData = {
      'type': 'register_face',
      'face_data': currentUnknownFaceImage,
      'name': name,
      'role': role,
    };

    channel?.sink.add(json.encode(registrationData));
    nameController.clear();
    roleController.clear();
  }

  void getSessions() {
    final message = {'type': 'get_sessions'};
    channel?.sink.add(json.encode(message));
    setState(() {
      showSessionDialog = true;
    });
  }

  void setSession(String sessionId) {
    final message = {
      'type': 'set_session',
      'session_id': sessionId,
    };
    channel?.sink.add(json.encode(message));
    setState(() {
      showSessionDialog = false;
    });
  }

  void getSessionParticipants(String sessionId) {
    final message = {
      'type': 'get_session_participants',
      'session_id': sessionId,
    };
    channel?.sink.add(json.encode(message));
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildSessionInfo() {
    if (currentSessionName == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, 0),
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: AppColors.accentMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.accent),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('No session selected', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  SizedBox(height: 2),
                  Text(
                    'Pick a session to start tracking attendance.',
                    style: TextStyle(color: AppColors.inkMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final presentCount = currentParticipants.where((p) => p['is_present'] == true).length;
    final totalCount = currentParticipants.length;
    final allPresent = totalCount > 0 && presentCount == totalCount;

    return Card(
      margin: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, 0),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primaryMuted,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.event_note_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentSessionName!,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: allPresent ? AppColors.successMuted : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Text(
                      '$presentCount/$totalCount present',
                      style: TextStyle(
                        color: allPresent ? AppColors.success : AppColors.inkMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => getSessionParticipants(currentSessionId!),
              icon: const Icon(Icons.groups_rounded, size: 18),
              label: const Text('View'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    channel?.sink.close();
    nameController.dispose();
    roleController.dispose();
    sessionNameController.dispose();
    sessionDescController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Camera'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (currentSessionName != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, size: 8, color: Colors.greenAccent),
                    const SizedBox(width: 6),
                    Text(
                      currentSessionName!,
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Session Info
              _buildSessionInfo(),

              // Video Stream
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Container(
                      width: double.infinity,
                      color: AppColors.ink,
                      child: Center(
                        child: latestFrame == null
                            ? const EmptyState(
                                icon: Icons.videocam_off_rounded,
                                title: 'Waiting for video',
                                message: 'Start the stream to see the live feed here.',
                              )
                            : Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  Image.memory(
                                    latestFrame!,
                                    gaplessPlayback: true,
                                    fit: BoxFit.contain,
                                  ),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(AppSpace.md),
                                    color: Colors.black.withOpacity(0.55),
                                    child: Text(
                                      currentSessionName != null
                                          ? 'Tracking attendance for $currentSessionName'
                                          : 'Face detected — select a session to track attendance',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),

              // Control Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.md),
                child: Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    _ControlButton(
                      onPressed: isStreaming ? null : startStream,
                      icon: Icons.play_arrow_rounded,
                      label: 'Start stream',
                      color: AppColors.success,
                    ),
                    _ControlButton(
                      onPressed: isStreaming ? stopStream : null,
                      icon: Icons.stop_rounded,
                      label: 'Stop stream',
                      color: AppColors.danger,
                    ),
                    _ControlButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ManagementMainScreen()),
                        );
                      },
                      icon: Icons.manage_accounts_rounded,
                      label: 'Manage',
                      color: AppColors.primary,
                    ),
                    _ControlButton(
                      onPressed: isStreaming && latestFrame != null ? captureAndRegisterFace : null,
                      icon: Icons.person_add_alt_1_rounded,
                      label: 'Register face',
                      color: AppColors.accent,
                    ),
                    _ControlButton(
                      onPressed: isStreaming ? getSessions : null,
                      icon: Icons.event_note_rounded,
                      label: 'Sessions',
                      color: AppColors.personPalette[3],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Registration Dialog
          if (showRegistrationDialog)
            _ModalScrim(
              child: _ModalCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Register new face',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    if (currentUnknownFaceImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          color: AppColors.surfaceMuted,
                          child: Image.memory(
                            base64Decode(currentUnknownFaceImage!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpace.lg),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    TextField(
                      controller: roleController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        prefixIcon: Icon(Icons.work_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                showRegistrationDialog = false;
                                nameController.clear();
                                roleController.clear();
                              });
                            },
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: submitRegistration,
                            child: const Text('Register'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Sessions Dialog
          if (showSessionDialog)
            _ModalScrim(
              child: _ModalCard(
                tall: true,
                child: Column(
                  children: [
                    const Text(
                      'Select session',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Expanded(
                      child: sessions.isEmpty
                          ? const EmptyState(
                              icon: Icons.event_busy_rounded,
                              title: 'No sessions available',
                              message: 'Create a session from the Manage screen first.',
                            )
                          : ListView.separated(
                              itemCount: sessions.length,
                              separatorBuilder: (_, __) => const SizedBox(height: AppSpace.sm),
                              itemBuilder: (context, index) {
                                final session = sessions[index];
                                return Card(
                                  child: ListTile(
                                    leading: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryMuted,
                                        borderRadius: BorderRadius.circular(AppRadius.sm),
                                      ),
                                      child: const Icon(Icons.event_note_rounded, color: AppColors.primary, size: 18),
                                    ),
                                    title: Text(
                                      session['name'] ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      (session['description'] as String?)?.isNotEmpty == true
                                          ? session['description']
                                          : 'No description',
                                      style: const TextStyle(color: AppColors.inkMuted),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.people_alt_rounded, color: AppColors.success),
                                          tooltip: 'View participants',
                                          onPressed: () => getSessionParticipants(session['id']),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                                          tooltip: 'Use this session',
                                          onPressed: () => setSession(session['id']),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            showSessionDialog = false;
                          });
                        },
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Participants Dialog
          if (showParticipantsDialog)
            _ModalScrim(
              child: _ModalCard(
                tall: true,
                child: Column(
                  children: [
                    const Text(
                      'Session participants',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Expanded(
                      child: currentParticipants.isEmpty
                          ? const EmptyState(
                              icon: Icons.people_outline_rounded,
                              title: 'No participants yet',
                              message: 'Add people to this session from the Manage screen.',
                            )
                          : ListView.separated(
                              itemCount: currentParticipants.length,
                              separatorBuilder: (_, __) => const SizedBox(height: AppSpace.sm),
                              itemBuilder: (context, index) {
                                final participant = currentParticipants[index];
                                final isPresent = participant['is_present'] == true;
                                return Card(
                                  child: ListTile(
                                    leading: PersonAvatar(
                                      name: (participant['name'] ?? '?') as String,
                                      active: isPresent,
                                    ),
                                    title: Text(
                                      participant['name'] ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(participant['role'] ?? '', style: const TextStyle(color: AppColors.inkMuted)),
                                        if (participant['last_seen'] != null)
                                          Text(
                                            'Last seen: ${DateTime.parse(participant['last_seen']).toString().split('.')[0]}',
                                            style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
                                          ),
                                      ],
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isPresent ? AppColors.successMuted : AppColors.surfaceMuted,
                                        borderRadius: BorderRadius.circular(AppRadius.lg),
                                      ),
                                      child: Text(
                                        isPresent ? 'Present' : 'Absent',
                                        style: TextStyle(
                                          color: isPresent ? AppColors.success : AppColors.inkMuted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            showParticipantsDialog = false;
                          });
                        },
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Semi-transparent backdrop used behind the full-screen modal cards below.
class _ModalScrim extends StatelessWidget {
  final Widget child;
  const _ModalScrim({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(child: child),
    );
  }
}

/// Shared white rounded card shell for the in-page modals (registration,
/// sessions, participants) so they all read as one family instead of three
/// separately styled popups.
class _ModalCard extends StatelessWidget {
  final Widget child;
  final bool tall;
  const _ModalCard({required this.child, this.tall = false});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      width: size.width * 0.9,
      height: tall ? size.height * 0.7 : null,
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: tall ? child : SingleChildScrollView(child: child),
    );
  }
}

/// A pill-shaped control button used in the bottom action bar. Keeps every
/// action the same shape and weight; only the accent color changes.
class _ControlButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final Color color;

  const _ControlButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? color : AppColors.surfaceMuted,
        foregroundColor: enabled ? Colors.white : AppColors.inkMuted,
        disabledBackgroundColor: AppColors.surfaceMuted,
        disabledForegroundColor: AppColors.inkMuted,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
    );
  }
}