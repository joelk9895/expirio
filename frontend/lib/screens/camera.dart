import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:http_parser/http_parser.dart';
import 'dart:async';
import 'dart:convert';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture = Future(() => null);
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _initializeCamera();
    _testAPI();
  }

  Future<void> _testAPI() async {
    try {
      print('Testing API connection...');
      final response = await http
          .post(
        Uri.parse('https://hksw4q5b-8000.inc1.devtunnels.ms/upload-image/'),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('API test request timed out');
        },
      );
      print('API test status code: ${response.statusCode}');
      print('API test response: ${response.body}');
    } catch (e) {
      print('API test error: $e');
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;
    _controller = CameraController(
      firstCamera,
      ResolutionPreset.medium,
    );
    return _controller.initialize();
  }

  Future<void> _takePictureAndUpload() async {
    try {
      setState(() {
        _isUploading = true;
      });

      print('Starting picture capture and upload process...');
      await _initializeControllerFuture;
      final XFile photo = await _controller.takePicture();
      var imageFile = File(photo.path);
      print('Picture taken at: ${photo.path}');

      var uri =
          Uri.parse('https://hksw4q5b-8000.inc1.devtunnels.ms/upload-image/');
      var request = http.MultipartRequest('POST', uri);

      var multipartFile = await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        filename: photo.path.split('/').last,
        contentType: MediaType('image', 'jpeg'),
      );

      request.files.add(multipartFile);
      print('Sending request...');

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = {};
        try {
          responseData = Map<String, dynamic>.from(
            jsonDecode(response.body) as Map,
          );
          print('Uploaded file details: $responseData');
        } catch (e) {
          print('Error parsing response: $e');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Image uploaded successfully!\nSaved as: ${responseData['filename'] ?? 'unknown'}'),
            ),
          );
          // Navigate back after successful upload
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload image: ${response.body}')),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Error: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera Feed')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              alignment: Alignment.center,
              children: [
                CameraPreview(_controller),
                if (_isUploading)
                  Container(
                    width: double.infinity,
                    color: Colors.black54,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.white,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Uploading image...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                Positioned(
                  bottom: 16,
                  child: FloatingActionButton(
                    onPressed: _isUploading ? null : _takePictureAndUpload,
                    child: _isUploading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : const Icon(Icons.camera),
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
