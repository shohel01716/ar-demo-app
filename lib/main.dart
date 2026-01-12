import 'package:flutter/material.dart';
import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AR Demo App',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const ARDemoScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ARDemoScreen extends StatefulWidget {
  const ARDemoScreen({Key? key}) : super(key: key);

  @override
  State<ARDemoScreen> createState() => _ARDemoScreenState();
}

class _ARDemoScreenState extends State<ARDemoScreen> {
  // ARCore controller to manage the AR session
  ArCoreController? arCoreController;

  // Nodes
  ArCoreNode? ballNode;
  ArCoreNode? backboardNode;
  ArCoreNode? hoopNode;

  // Game/Physics constants
  final vector.Vector3 initialBallPosition = vector.Vector3(0.0, -0.5, -1.0);
  final vector.Vector3 hoopPosition = vector.Vector3(0.0, 0.5, -3.0);

  // Current position of the ball
  late vector.Vector3 currentBallPosition;

  // Game State
  bool isThrowing = false;
  bool _cameraPermissionGranted = false;
  int score = 0;

  @override
  void initState() {
    super.initState();
    currentBallPosition = vector.Vector3.copy(initialBallPosition);
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _cameraPermissionGranted = status.isGranted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AR Basketball'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Score: $score',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: !_cameraPermissionGranted
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Camera permission is required for AR',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _checkPermission,
                    child: const Text('Grant Permission'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                ArCoreView(
                  onArCoreViewCreated: _onArCoreViewCreated,
                  enableTapRecognizer: true,
                ),
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: isThrowing ? null : _throwBall,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child:
                            const Text('Throw', style: TextStyle(fontSize: 18)),
                      ),
                      ElevatedButton(
                        onPressed: _resetBall,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child:
                            const Text('Reset', style: TextStyle(fontSize: 18)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _onArCoreViewCreated(ArCoreController controller) {
    arCoreController = controller;
    _addBasketballHoop();
    _addBallToScene();
  }

  void _addBasketballHoop() {
    // 1. Backboard (White Board)
    final backboardMaterial = ArCoreMaterial(
      color: Colors.white,
      metallic: 0.0,
      roughness: 0.1,
    );
    final backboardShape = ArCoreCube(
      materials: [backboardMaterial],
      size: vector.Vector3(1.2, 0.9, 0.05), // Width, Height, Depth
    );
    backboardNode = ArCoreNode(
      shape: backboardShape,
      position: vector.Vector3(
          hoopPosition.x, hoopPosition.y + 0.45, hoopPosition.z - 0.1),
    );

    // 2. Hoop/Rim (represented as an Orange Box for simplicity)
    // In a real app, use a proper 3D model
    final hoopMaterial = ArCoreMaterial(
      color: Colors.deepOrange,
      metallic: 1.0,
    );
    final hoopShape = ArCoreCube(
      materials: [hoopMaterial],
      size: vector.Vector3(0.45, 0.05, 0.45), // A flat square rim
    );
    hoopNode = ArCoreNode(
      shape: hoopShape,
      position: hoopPosition,
    );

    arCoreController?.addArCoreNode(backboardNode!);
    arCoreController?.addArCoreNode(hoopNode!);
  }

  void _addBallToScene() {
    final material = ArCoreMaterial(
      color: Colors.orange,
      metallic: 0.1,
      roughness: 0.5,
      reflectance: 0.5,
    );
    final sphere = ArCoreSphere(radius: 0.12, materials: [material]);

    ballNode = ArCoreNode(
      name: 'basketball',
      shape: sphere,
      position: currentBallPosition,
    );

    arCoreController?.addArCoreNode(ballNode!);
  }

  void _throwBall() {
    if (ballNode == null || isThrowing) return;
    setState(() => isThrowing = true);

    // Initial position
    final start = currentBallPosition.clone();

    // Target position (The hoop)
    // We add some "skill" variance based on nothing for now, but in future could use sensors
    // Perfect shot logic:
    final end = hoopPosition.clone();

    // Animation loop (simulating projectile motion)
    int steps = 25;
    double durationSecs = 1.0;
    double timePerStep = durationSecs / steps;
    int currentStep = 0;

    Future.doWhile(() async {
      await Future.delayed(
          Duration(milliseconds: (timePerStep * 1000).round()));

      if (currentStep > steps || ballNode == null) {
        // Check scoring at the end
        _checkScore(currentBallPosition);
        setState(() => isThrowing = false);
        return false;
      }

      double t = currentStep / steps; // 0.0 to 1.0

      // Linear interpolation for X and Z (straight text)
      double x = start.x + (end.x - start.x) * t;
      double z = start.z + (end.z - start.z) * t;

      // Parabolic arc for Y: y = startY + (distY * t) + (4 * height * t * (1-t))
      // This adds an "arc" height of 0.8 meters
      double arcHeight = 0.8;
      double y =
          start.y + (end.y - start.y) * t + (4 * arcHeight * t * (1 - t));

      vector.Vector3 newPos = vector.Vector3(x, y, z);

      _updateBallPosition(newPos);
      currentBallPosition = newPos;

      currentStep++;
      return true;
    });
  }

  void _updateBallPosition(vector.Vector3 position) {
    arCoreController?.removeNode(nodeName: ballNode!.name);

    final material = ArCoreMaterial(color: Colors.orange);
    final sphere = ArCoreSphere(radius: 0.12, materials: [material]);

    ballNode = ArCoreNode(
      name: 'basketball',
      shape: sphere,
      position: position,
    );
    arCoreController?.addArCoreNode(ballNode!);
  }

  void _checkScore(vector.Vector3 finalPos) {
    // Simple distance check: if ball is close enough to hoop position
    double distance = finalPos.distanceTo(hoopPosition);
    if (distance < 0.3) {
      // 30cm tolerance
      setState(() {
        score++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Basket! +1 Point')),
      );
    }
  }

  void _resetBall() {
    if (ballNode != null) {
      arCoreController?.removeNode(nodeName: ballNode!.name);
    }

    currentBallPosition = vector.Vector3.copy(initialBallPosition);
    _addBallToScene();

    setState(() => isThrowing = false);
  }

  @override
  void dispose() {
    arCoreController?.dispose();
    super.dispose();
  }
}
