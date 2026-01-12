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

  // Reference to the ball node so we can move it
  ArCoreNode? ballNode;

  // Initial position of the ball (1 meter in front of camera)
  final vector.Vector3 initialPosition = vector.Vector3(0.0, 0.0, -1.0);

  // Current position of the ball
  vector.Vector3 currentPosition = vector.Vector3(0.0, 0.0, -1.0);

  // Flag to track if ball is being thrown
  bool isThrowing = false;

  bool _cameraPermissionGranted = false;

  @override
  void initState() {
    super.initState();
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
      appBar: AppBar(title: const Text('AR Demo App'), centerTitle: true),
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
                // ARCore camera view - this displays the device camera with AR overlay
                ArCoreView(
                  onArCoreViewCreated: _onArCoreViewCreated,
                  enableTapRecognizer: true,
                ),

                // Floating UI buttons overlaid on top of AR view
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Throw button - moves ball forward
                      ElevatedButton(
                        onPressed: isThrowing ? null : _throwBall,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey,
                        ),
                        child:
                            const Text('Throw', style: TextStyle(fontSize: 18)),
                      ),

                      // Reset button - returns ball to initial position
                      ElevatedButton(
                        onPressed: _resetBall,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
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

  /// Called when ARCoreView is created and ready
  /// This is where we initialize the AR scene and add 3D objects
  void _onArCoreViewCreated(ArCoreController controller) {
    arCoreController = controller;

    // Add the 3D ball to the AR scene
    _addBallToScene();
  }

  /// Creates and adds a 3D sphere (ball) to the AR scene
  void _addBallToScene() {
    // Define the ball's material (color and texture properties)
    final material = ArCoreMaterial(
      color: Colors.red,
      metallic: 0.8, // Makes it look slightly metallic
      roughness: 0.4, // Controls how smooth/rough the surface appears
    );

    // Create a sphere shape with 0.1 meter radius (10 cm diameter)
    final sphere = ArCoreSphere(radius: 0.1, materials: [material]);

    // Create an AR node - this is a container that holds the 3D object
    // and defines its position, rotation, and scale in the AR world
    ballNode = ArCoreNode(
      shape: sphere,
      position: initialPosition, // Place 1 meter in front of camera
      rotation: vector.Vector4(0, 0, 0, 0), // No rotation
    );

    // Add the node to the AR scene
    arCoreController?.addArCoreNode(ballNode!);
  }

  /// Simulates throwing the ball forward (toward the wall)
  /// This is a fake throw - just moving the position, no real physics
  void _throwBall() {
    if (ballNode == null || isThrowing) return;

    setState(() {
      isThrowing = true;
    });

    // Calculate the target position (3 meters forward from current position)
    final targetPosition = vector.Vector3(
      currentPosition.x,
      currentPosition.y,
      currentPosition.z - 3.0, // Move 3 meters away (negative Z is forward)
    );

    // Animate the ball movement over time
    // This creates a simple linear movement from current to target position
    _animateBallMovement(targetPosition);
  }

  /// Animates the ball from current position to target position
  void _animateBallMovement(vector.Vector3 targetPosition) {
    const steps = 20; // Number of position updates
    const stepDuration =
        40; // Duration per step in milliseconds (800ms total / 20 steps)

    // Calculate how much to move in each step
    final deltaX = (targetPosition.x - currentPosition.x) / steps;
    final deltaY = (targetPosition.y - currentPosition.y) / steps;
    final deltaZ = (targetPosition.z - currentPosition.z) / steps;

    int currentStep = 0;

    // Update position gradually over time
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: stepDuration));

      if (currentStep < steps && ballNode != null) {
        // Update current position
        currentPosition = vector.Vector3(
          currentPosition.x + deltaX,
          currentPosition.y + deltaY,
          currentPosition.z + deltaZ,
        );

        // Remove old ball node
        arCoreController?.removeNode(nodeName: ballNode!.name);

        // Create updated ball at new position
        final material = ArCoreMaterial(
          color: Colors.red,
          metallic: 0.8,
          roughness: 0.4,
        );

        final sphere = ArCoreSphere(radius: 0.1, materials: [material]);

        ballNode = ArCoreNode(
          shape: sphere,
          position: currentPosition,
          rotation: vector.Vector4(0, 0, 0, 0),
        );

        // Add updated ball to scene
        arCoreController?.addArCoreNode(ballNode!);

        currentStep++;
        return true; // Continue loop
      } else {
        // Animation complete
        setState(() {
          isThrowing = false;
        });
        return false; // Exit loop
      }
    });
  }

  /// Resets the ball to its initial position (1 meter in front)
  void _resetBall() {
    if (ballNode == null) return;

    // Remove current ball from scene
    arCoreController?.removeNode(nodeName: ballNode!.name);

    // Reset position to initial
    currentPosition = vector.Vector3(
      initialPosition.x,
      initialPosition.y,
      initialPosition.z,
    );

    // Create ball at initial position
    final material = ArCoreMaterial(
      color: Colors.red,
      metallic: 0.8,
      roughness: 0.4,
    );

    final sphere = ArCoreSphere(radius: 0.1, materials: [material]);

    ballNode = ArCoreNode(
      shape: sphere,
      position: currentPosition,
      rotation: vector.Vector4(0, 0, 0, 0),
    );

    // Add ball back to scene at initial position
    arCoreController?.addArCoreNode(ballNode!);

    setState(() {
      isThrowing = false;
    });
  }

  @override
  void dispose() {
    // Clean up AR session when screen is disposed
    arCoreController?.dispose();
    super.dispose();
  }
}
