import 'dart:io';
import 'dart:typed_data';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:drawie/helpers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'drawing.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drawie',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  final _urlController = TextEditingController();
  var _isProcessing = false;
  dynamic _image;

  bool _isValidImageURL(String url) => Uri.parse(url).isAbsolute && lookupMimeType(url)?.split('/').first == 'image';

  _submit() async {
    final url = _urlController.text;
    if (!_isValidImageURL(url)) return h.showDialog(type: DialogType.ERROR, message: "Please enter valid image URL!");
    final result = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DrawingPage(background: url),),) as Uint8List?;
    if (!mounted || result == null) return;
    setState(() {
      _image = result;
    });
  }

  _back() {
    setState(() {
      _image = null;
    });
  }

  _save() async {
    setState(() {
      _isProcessing = true;
    });
    if (kIsWeb) {
      h.showToast("Uploading image...");
      await Future.delayed(const Duration(milliseconds: 3000));
      h.showToast("Your drawie has been uploaded to server!");
    } else {
      final fileName = "${DateTime.now().millisecondsSinceEpoch}";
      final filePath = await h.getDownloadPath('$fileName.png');
      final file = await File(filePath).writeAsBytes(_image);
      h.showToast("Your drawie has been saved in Download folder");
      h.shareFile(file.path, message: "Look! I've made my drawie, LOL");
    }
    setState(() {
      _isProcessing = false;
      _image = null;
    });
  }

  @override
  void initState() {
    _urlController.text = 'https://i.imgur.com/jiw5Da0.jpg';
    h = MyHelper(context);
    super.initState();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _image != null ? null : AppBar(title: const Text("Drawie"),),
      body: SafeArea(
        child: Center(
          child: _isProcessing ? const CircularProgressIndicator.adaptive() : SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _image == null ? [
                const Text("Paste image URL here:", textAlign: TextAlign.center,),
                const SizedBox(height: 20,),
                TextField(controller: _urlController,),
                const SizedBox(height: 20,),
                ElevatedButton(onPressed: _submit, child: const Text("Okay"))
              ] : [
                Row(
                  children: [
                    Expanded(child: ElevatedButton(onPressed: _back, child: const Text("Back"))),
                    const SizedBox(width: 20,),
                    Expanded(child: ElevatedButton(onPressed: _save, child: const Text("Save"))),
                  ],
                ),
                const SizedBox(height: 20,),
                Image.memory(_image),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
