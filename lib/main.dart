import 'package:flutter/material.dart';
import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' as math;

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
  final List<vector.Vector3> rimSegments =
      []; // Store rim segment positions for physics
  final double rimRadius = 0.25;

  // Current position of the ball
  late vector.Vector3 currentBallPosition;

  // Game State
  bool isThrowing = false;
  bool _cameraPermissionGranted = false;
  int score = 0;

  // Physics
  final double gravity = -9.8;
  final double deltaT = 0.02; // 20ms physics step

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
                GestureDetector(
                  onPanEnd: (details) {
                    if (!isThrowing && ballNode != null) {
                      _handleSwipe(details.velocity);
                    }
                  },
                  child: Container(
                    color: Colors.transparent,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _resetBall,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Reset Ball',
                            style: TextStyle(fontSize: 18)),
                      ),
                    ],
                  ),
                ),
                const Positioned(
                  bottom: 150,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      "Swipe Up to Throw!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                      ),
                    ),
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

    // 2. Rim (Ring of nodes to simulate an open hoop)
    final rimMaterial = ArCoreMaterial(
      color: Colors.deepOrange,
      metallic: 1.0,
      reflectance: 0.8,
    );

    rimSegments.clear();
    int segments = 16;
    double angleStep = (2 * 3.14159) / segments;

    for (int i = 0; i < segments; i++) {
      double angle = i * angleStep;
      double x = rimRadius * math.cos(angle);
      double z = rimRadius * math.sin(angle);

      final segmentShape = ArCoreSphere(
        materials: [rimMaterial],
        radius: 0.02, // Thickness of the rim
      );

      // Adjust position relative to hoop center
      // Note: Hoop is flat on X-Z plane (since Y is Up)
      final pos = vector.Vector3(
          hoopPosition.x + x, hoopPosition.y, hoopPosition.z + z);

      rimSegments.add(pos);

      final segmentNode = ArCoreNode(
        shape: segmentShape,
        position: pos,
      );
      arCoreController?.addArCoreNode(segmentNode);
    }

    // 3. Visual Net (Cylinder)
    final netMaterial = ArCoreMaterial(
      color: Colors.white.withOpacity(0.5),
      textureBytes: null, // Could add a grid texture here if available
      metallic: 0.0,
      roughness: 1.0,
    );

    final netShape = ArCoreCylinder(
      materials: [netMaterial],
      radius: rimRadius * 0.9,
      height: 0.4,
    );

    final netNode = ArCoreNode(
      shape: netShape,
      position: vector.Vector3(
          hoopPosition.x,
          hoopPosition.y - 0.2, // Hangs below the rim
          hoopPosition.z),
    );
    arCoreController?.addArCoreNode(netNode);

    // Add backboard with corrected position
    backboardNode = ArCoreNode(
      shape: backboardShape,
      position: vector.Vector3(hoopPosition.x, hoopPosition.y + 0.45,
          hoopPosition.z - 0.4), // Moved further back
    );
    arCoreController?.addArCoreNode(backboardNode!);
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

  void _handleSwipe(Velocity velocity) {
    setState(() => isThrowing = true);

    // Map 2D Swipe Velocity to 3D Force
    // Y (Screen Up) -> Z (World Forward) & Y (World Up)
    // X (Screen Right) -> X (World Right)

    double sensitivity = 0.002;
    double forwardForce = -velocity.pixelsPerSecond.dy *
        sensitivity; // Swipe Up is negative Y pixels
    double upForce = forwardForce * 0.8; // Add some arc
    double sideForce = velocity.pixelsPerSecond.dx * sensitivity * 0.5;

    // Minimum throw strength
    if (forwardForce < 1.0) forwardForce = 1.0;

    // Initial Velocity Vector
    // Note: Z is negative into the screen
    vector.Vector3 ballVelocity =
        vector.Vector3(sideForce, upForce, -forwardForce);

    _runPhysicsLoop(ballVelocity);
  }

  void _runPhysicsLoop(vector.Vector3 velocity) {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 20));

      if (!isThrowing || ballNode == null) return false;

      // 1. Gravity
      velocity.y += gravity * deltaT;

      // 2. Update Position
      currentBallPosition += velocity * deltaT;

      // 3. Collision Detection (Backboard)
      if (backboardNode != null) {
        // Backboard Plane Z roughly at hoopPosition.z - 0.4
        // Face is at -0.4 + thickness/2 = -0.375 usually?
        // Let's assume backboard surface is at (hoopPosition.z - 0.35)
        double backboardZ = hoopPosition.z - 0.35;

        if (currentBallPosition.z < backboardZ &&
            currentBallPosition.z > backboardZ - 0.3 && // Not too far behind
            currentBallPosition.y > hoopPosition.y &&
            currentBallPosition.y < hoopPosition.y + 1.0 &&
            currentBallPosition.x > -0.6 &&
            currentBallPosition.x < 0.6) {
          // Bounce off backboard
          velocity.z = -velocity.z * 0.6; // Damped bounce
          currentBallPosition.z = backboardZ + 0.05; // Push out
        }
      }

      // 4. Collision Detection (Rim)
      for (final segmentPos in rimSegments) {
        double dist = currentBallPosition.distanceTo(segmentPos);
        // Ball radius 0.12 + Rim thickness 0.02 = 0.14
        if (dist < 0.14) {
          // Simple elastic collision response
          // Vector from rim to ball
          vector.Vector3 normal = currentBallPosition - segmentPos;
          normal.normalize();

          // Reflect velocity
          // v_new = v - 2(v . n)n
          double dot = velocity.dot(normal);
          if (dot < 0) {
            // Only bounce if moving towards the rim
            velocity = velocity - normal * (2 * dot) * 0.7; // 0.7 restitution
            // Push out to prevent sticking
            currentBallPosition = segmentPos + normal * 0.15;
            // hitRim = true;
            break; // Handle one collision per frame for simplicity
          }
        }
      }

      // 5. Floor/Out of Bounds Collision
      if (currentBallPosition.y < -2.0 || currentBallPosition.z < -10.0) {
        setState(() => isThrowing = false);
        return false;
      }

      // 6. Hoop Scoring
      // Check if ball passes THROUGH the hoop plane closer to center
      // Plane is Y = hoopPosition.y
      if (currentBallPosition.distanceTo(hoopPosition) < 0.20 &&
          (currentBallPosition.y - hoopPosition.y).abs() < 0.1) {
        // ensure it's moving downwards
        if (velocity.y < 0) {
          _checkScore();
          // After score, maybe let it fall through?
          // Just reset for now or let it continue
          // We let it continue to fall through the "net"
        }
      }

      // Update Visuals
      _updateBallPosition(currentBallPosition);

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

  void _checkScore() {
    setState(() {
      score++;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Basket! +1 Point'),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
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
