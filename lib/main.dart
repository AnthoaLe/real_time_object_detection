import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite/tflite.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Real Time Object Detection',
      theme: ThemeData(
        primarySwatch: Colors.purple,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home Page'),
      ),
      body: Center(
          child: Column(
            children: <Widget> [
              ElevatedButton(
                child: Text('Real Time Detection'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RealTimeDetectionScreen())
                  );
                },
              )
            ],
          )
        ),
    );
  }
}

class RealTimeDetectionScreen extends StatefulWidget {
  const RealTimeDetectionScreen({Key? key}) : super(key: key);

  @override
  _RealTimeDetectionScreenState createState() => _RealTimeDetectionScreenState();
}

class _RealTimeDetectionScreenState extends State<RealTimeDetectionScreen> {
  late CameraController _controller;
  late CameraImage _image;
  bool isDetecting = false;
  List<dynamic>? _recognitions = [];

  @override void initState() {
    super.initState();
    _controller = CameraController(
      _cameras[0],
      ResolutionPreset.max,
      imageFormatGroup: ImageFormatGroup.yuv420, // ONLY WORKS ON ANDROID
    );
    _controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
      loadModel();
      _controller.startImageStream((image) {
        if (!isDetecting) {
          _image = image;
          isDetecting = true;
          runModel();
        }

      });
    }).catchError((Object error) {
      if (error is CameraException) {
        switch (error.code) {
          case 'CameraAccessDenied':
            print('User denied camera access');
            break;
          default:
            print('Exception occured');
            break;
        }
      }
    });
  }

  @override void dispose() {
    _controller?.dispose();
    Tflite?.close();
    super.dispose();
  }

  Future<void> loadModel() async {
    print('before  loadModel');
    Tflite?.close();
    await Tflite.loadModel(
        model: 'assets/ssd_mobilenet.tflite',
        labels: 'assets/labels.txt',
        numThreads: 1, // defaults to 1
        isAsset: true, // defaults to true, set to false to load resources outside assets
        useGpuDelegate: false // defaults to false, set to true to use GPU delegate
    ).then((result) {
      print(result);
      print('after loadModel');
    });
  }

  Future<void> runModel() async {
    print('before detectObjectOnFrame');
    await Tflite.detectObjectOnFrame(
        bytesList: _image.planes.map((plane) {return plane.bytes;}).toList(),// required
        model: "SSDMobileNet",
        imageHeight: _image.height,
        imageWidth: _image.width,
        imageMean: 127.5,   // defaults to 127.5
        imageStd: 127.5,    // defaults to 127.5
        rotation: 90,       // defaults to 90, Android only
        numResultsPerClass: 2,      // defaults to 5
        threshold: 0.3,     // defaults to 0.1
        asynch: true        // defaults to true
    ).then((recognitions) {
      print('then start');
      // setState(() {});
      isDetecting = false;
      print(recognitions);
      // print(recognitions.runtimeType);   // List<Object?>
      setState(() {
        _recognitions = recognitions;
      });
      print('then end');
      // setState(() {});
    });
    print('after detectObjectOnFrame');
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.value.isInitialized) {
      return Stack(
        children: <Widget>[
          CameraPreview(_controller),
          BoundingBoxes(recognitions: _recognitions),
        ],
      );
    }
    return Container(
      child: Text('Camera Denied'),
    );
  }
}

class BoundingBoxes extends StatefulWidget {
  const BoundingBoxes({Key? key, required this.recognitions}) : super(key: key);

  final List<dynamic>? recognitions;

  @override
  _BoundingBoxesState createState() => _BoundingBoxesState();
}

class _BoundingBoxesState extends State<BoundingBoxes> {
  List<Widget> _renderBoundingBoxes() {
    return widget.recognitions!.asMap().map((i, re) {
      return MapEntry(
        i,
          Positioned(
            left: 0,
            top: 0,
            child: Container(
                child: Text("${re['detectedClass']}"),
                decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.red,
                      width: 3.0,
                    )
                )
            ),
          ),
      )).toList();
  }
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _renderBoundingBoxes()
    );
  }
}
