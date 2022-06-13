import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'drawing/drawn_line.dart';
import 'drawing/sketcher.dart';
import 'helpers.dart';

late final MyHelper h;

const BACKGROUND_COLOR = Colors.white;
const APP_UI_COLOR_MAIN = Colors.blue;
const APP_UI_COLOR_SECONDARY = Colors.grey;
const APP_UI_COLOR_DANGER = Colors.red;
const APP_UI_COLOR_ACCENT = Colors.deepPurpleAccent;
const APP_UI_COLOR_INFO = Colors.blueAccent;

class DrawingPage extends StatefulWidget {
  const DrawingPage({this.background, this.prevDrawing, Key? key}) : super(key: key);
  final String? background;
  final String? prevDrawing;

  @override
  DrawingPageState createState() => DrawingPageState();
}

const _zoomScaleMin = 0.1;
const _zoomScaleMax = 3.0;

class DrawingPageState extends State<DrawingPage> {
  final _globalKey = GlobalKey();
  final _transformationController = TransformationController();
  var _selectedColor = Colors.black;
  var _selectedWidth = 5.0;
  var _lines = <dynamic>[];
  var _isAddText = false;
  var _isEraser = false;
  var _isPan = false;
  var _startPoint = const Offset(0, 0);
  var _startX = 0.0;
  var _startY = 0.0;
  var _currentZoom = 1.0;
  var _zoom = 1.0;
  DrawnLine? _line;
  DrawnText? _text;
  ui.Image? _background;
  ui.Image? _prevDrawing;

  final linesStreamController = StreamController<List<dynamic>>.broadcast();
  final currentLineStreamController = StreamController<dynamic>.broadcast();

  Color get _lineColor => _isEraser ? Colors.white : _selectedColor;

  _save() async {
    try {
      // capture
      final boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(); // not supported in web html renderer https://github.com/flutter/flutter/issues/57631, https://github.com/flutter/flutter/issues/47721
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final screenshot = byteData?.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
      if (screenshot == null) return h.showToast("Failed to save canvas to image.");
      if (mounted) Navigator.pop(context, screenshot);
    } catch (e) {
      h.showToast("Failed to save canvas to image.");
    }
  }

  _clear() {
    setState(() {
      _lines = [];
      _line = null;
    });
  }

  _undo() {
    if (_isDrawText) {
      setState(() {
        _isAddText = false;
        _text = null;
      });
      return;
    }
    setState(() {
      _lines.removeLast();
      _line = null;
    });
  }

  double get _currentPanX => _transformationController.value.getTranslation().x;
  double get _currentPanY => _transformationController.value.getTranslation().y;
  bool get _isDrawText => _isAddText && _text != null;

  _zoomIn() {
    if (_isDrawText) {
      if (_text!.size != null) {
        setState(() {
          _text!.size = _text!.size! + 2;
        });
      }
      return;
    }
    _zoomTo(zoom: _currentZoom + .2);
    _zoom = _currentZoom;
  }

  _zoomOut() {
    if (_isDrawText) {
      if (_text!.size != null && _text!.size! > 5.0) {
        setState(() {
          _text!.size = _text!.size! - 2;
        });
      }
      return;
    }
    _zoomTo(zoom: _currentZoom - .2);
    _zoom = _currentZoom;
  }

  _zoomTo({double? panX, double? panY, double? zoom}) {
    final dx = _startX + (panX??0);
    final dy = _startY + (panY??0);
    zoom ??= _currentZoom;
    final scaleTarget = zoom > _zoomScaleMax ? _zoomScaleMax : zoom < _zoomScaleMin ? _zoomScaleMin : zoom;
    _currentZoom = scaleTarget;
    _transformationController.value = Matrix4(
      scaleTarget, 0, 0, 0,
      0, scaleTarget, 0, 0,
      0, 0, 1, 0,
      dx, dy, 0, 1,
    );
  }

  Future<ui.Image> loadUiAssetImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final list = Uint8List.view(data.buffer);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(list, completer.complete);
    return completer.future;
  }

  Future<ui.Image?> loadUiNetworkImage(String? url) async {
    if (url == null) return null;
    final http.Response response = await http.get(Uri.parse(url));
    final list = response.bodyBytes;
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(list, completer.complete);
    return completer.future;
  }

  @override
  void initState() {
    final backgroundUrl = widget.background;
    final prevDrawingUrl = widget.prevDrawing;
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (backgroundUrl != null) _background = await loadUiNetworkImage(backgroundUrl);
      if (prevDrawingUrl != null) _prevDrawing = await loadUiNetworkImage(prevDrawingUrl);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textWidget = _text == null ? Container() : Material(
      color: Colors.transparent,
      child: Row(
        children: [
          GestureDetector(
            onTap: _addText,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
              ),
              padding: const EdgeInsets.all(10),
              child: Text(_text!.text, style: TextStyle(
                color: _selectedColor,
                fontWeight: FontWeight.bold,
                fontSize: _text!.size ?? _selectedWidth,
              ),),
            ),
          ),
          const SizedBox(width: 12.0,),
          GestureDetector(
            onTap: _submitText,
            child: const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.greenAccent,
              child: Icon(
                Icons.done_rounded,
                size: 20.0,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    return WillPopScope(
      onWillPop: () async {
        if (_lines.isNotEmpty) return await h.showConfirmDialog("Are you sure you want to discard this drawing?", title: "Discard Drawing");
        return true;
      },
      child: Scaffold(
        backgroundColor: BACKGROUND_COLOR,
        body: SafeArea(
          child: Stack(
            children: [
              InteractiveViewer(
                panEnabled: _isPan || _isDrawText,
                scaleEnabled: _isPan || _isDrawText,
                minScale: _zoomScaleMin,
                maxScale: _zoomScaleMax,
                transformationController: _transformationController,
                onInteractionStart: (scaleDetails) {
                  if (_isPan || _isDrawText) {
                    _startPoint = scaleDetails.focalPoint;
                    _startX = _currentPanX;
                    _startY = _currentPanY;
                    return;
                  }
                  final box = context.findRenderObject() as RenderBox;
                  final point = box.globalToLocal(scaleDetails.focalPoint);
                  final pdtop = MediaQuery.of(context).padding.top;
                  final fixed = Offset(point.dx / _currentZoom - _currentPanX / _currentZoom, (point.dy - pdtop) / _currentZoom - _currentPanY / _currentZoom);
                  _line = DrawnLine(
                    [fixed],
                    _lineColor,
                    _selectedWidth,
                    zoom: _currentZoom,
                    panX: _currentPanX,
                    panY: _currentPanY,
                  );
                },
                onInteractionUpdate: (scaleUpdates){
                  if (_isPan || _isDrawText) {
                    final newOffset = scaleUpdates.focalPoint;
                    _zoomTo(
                      panX: newOffset.dx - _startPoint.dx,
                      panY: newOffset.dy - _startPoint.dy,
                      zoom: scaleUpdates.pointerCount == 1 ? _zoom : _zoom * scaleUpdates.scale,
                    );
                    return;
                  }
                  if (scaleUpdates.pointerCount == 0) return;
                  final box = context.findRenderObject() as RenderBox;
                  final point = box.globalToLocal(scaleUpdates.focalPoint);
                  final pdtop = MediaQuery.of(context).padding.top;
                  final fixed = Offset(point.dx / _currentZoom - _currentPanX / _currentZoom, (point.dy - pdtop) / _currentZoom - _currentPanY / _currentZoom);
                  final List<Offset> path = List.from(_line?.path ?? [])..add(fixed);
                  _line = DrawnLine(
                    path,
                    _lineColor,
                    _selectedWidth,
                    zoom: _currentZoom,
                    panX: _currentPanX,
                    panY: _currentPanY,
                  );
                  currentLineStreamController.add(_line!);
                },
                onInteractionEnd: (scaleEndDetails) {
                  if (_isPan || _isDrawText) {
                    setState(() {
                      _startX = _currentPanX;
                      _startY = _currentPanY;
                      _zoom = _currentZoom;
                    });
                    return;
                  }
                  if (_line == null) return;
                  setState(() {
                    _lines.add(_line!..isEraser = _isEraser);
                    _line = null;
                  });
                  linesStreamController.add(_lines);
                },
                child: Stack(
                  children: [
                    buildAllPaths(context),
                    buildCurrentPath(context),
                    Positioned(
                      left: (_text?.offset?.dx ?? 0) - 10 * _zoom,
                      top: (_text?.offset?.dy ?? 0) - 10 * _zoom,
                      child: _isDrawText ? Draggable(
                        feedback: Transform.scale(
                          origin: const Offset(0, 0),
                          scale: _zoom,
                          child: textWidget,
                        ),
                        childWhenDragging: const SizedBox(),
                        child: textWidget,
                        onDragEnd: (dragDetails) {
                          final pdtop = MediaQuery.of(context).padding.top;
                          setState(() {
                            _text!.offset = Offset(
                              (dragDetails.offset.dx - _currentPanX) / _zoom + 10 * _zoom,
                              (dragDetails.offset.dy - _currentPanY - pdtop) / _zoom + 10 * _zoom,
                            );
                          });
                        },
                      ) : Container()
                    ),
                  ],
                ),
              ),
              buildStrokeToolbar(),
              buildColorToolbar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildCurrentPath(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        color: Colors.transparent,
        child: StreamBuilder<dynamic>(
          stream: currentLineStreamController.stream,
          builder: (context, snapshot) {
            return CustomPaint(
              painter: Sketcher(
                lines: _line == null ? [] : [_line!],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildAllPaths(BuildContext context) {
    return RepaintBoundary(
      key: _globalKey,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        color: BACKGROUND_COLOR,
        child: StreamBuilder<List<dynamic>>(
          stream: linesStreamController.stream,
          builder: (context, snapshot) {
            return CustomPaint(
              painter: Sketcher(
                background: _background,
                prevDrawing: _prevDrawing,
                lines: _lines,
              ),
            );
          },
        ),
      ),
    );
  }

  _addText() async {
    setState(() {
      _isAddText = true;
    });
    final screenSize = MediaQuery.of(context).size;
    final text = await h.showDialog(
      body: AddText(_text),
      title: _text == null ? "Add Text" : "Edit Text",
    ) as String?;
    setState(() {
      if (text != null) {
        _text = DrawnText(
          text,
          color: _selectedColor,
          size: _selectedWidth,
          zoom: _currentZoom,
          offset: Offset(
            (-_currentPanX + screenSize.width/2) / _currentZoom,
            (-_currentPanY + screenSize.height/2) / _currentZoom
          ),
        );
      } else if (_text == null) {
        _isAddText = false;
      }
    });
  }

  _submitText() {
    if (_text == null) return;
    setState(() {
      _lines.add(_text!);
      _isAddText = false;
      _text = null;
    });
    linesStreamController.add(_lines);
  }

  Widget buildStrokeToolbar() {
    return Positioned(
      bottom: 108.0,
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _zoomIn,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: _isAddText ? APP_UI_COLOR_MAIN : APP_UI_COLOR_SECONDARY,
              child: Icon(
                _isAddText ? Icons.text_increase_rounded : Icons.zoom_in_rounded,
                size: 20.0,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8,),
          GestureDetector(
            onTap: _zoomOut,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: _isAddText ? APP_UI_COLOR_MAIN : APP_UI_COLOR_SECONDARY,
              child: Icon(
                _isAddText ? Icons.text_decrease_rounded : Icons.zoom_out_rounded,
                size: 20.0,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8,),
          GestureDetector(
            onTap: _addText,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: _isAddText ? APP_UI_COLOR_MAIN : APP_UI_COLOR_SECONDARY,
              child: const Icon(
                Icons.text_fields_rounded,
                size: 20.0,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8,),
          GestureDetector(
            onTap: () {
              setState(() {
                _isEraser = !_isEraser;
              });
            },
            child: CircleAvatar(
              radius: 16,
              backgroundColor: _isEraser ? APP_UI_COLOR_DANGER : APP_UI_COLOR_SECONDARY,
              child: const Icon(
                Icons.backspace_rounded,
                size: 20.0,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8,),
          GestureDetector(
            onTap: _isDrawText ? null : () {
              setState(() {
                _isPan = !_isPan;
              });
            },
            child: CircleAvatar(
              radius: 16,
              backgroundColor: _isPan || _isDrawText ? APP_UI_COLOR_MAIN : APP_UI_COLOR_SECONDARY,
              child: const Icon(
                Icons.pan_tool_rounded,
                size: 20.0,
                color: Colors.white,
              ),
            ),
          ),
          _isPan || _isDrawText ? const SizedBox() : const SizedBox(height: 20,),
          _isPan || _isDrawText ? const SizedBox() : buildStrokeButton(5.0),
          _isPan || _isDrawText ? const SizedBox() : buildStrokeButton(10.0),
          _isPan || _isDrawText ? const SizedBox() : buildStrokeButton(15.0),
        ],
      ),
    );
  }

  Widget buildStrokeButton(double strokeWidth) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedWidth = strokeWidth;
          _text?.size = strokeWidth;
        });
      },
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Container(
          width: strokeWidth * 2,
          height: strokeWidth * 2,
          decoration: BoxDecoration(color: _selectedColor, borderRadius: BorderRadius.circular(50.0)),
        ),
      ),
    );
  }

  Widget buildColorToolbar() {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                buildUndoButton(),
                const SizedBox(width: 10.0,),
                buildSaveButton(),
              ],
            ),
            const SizedBox(height: 8,),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Color>[
                const Color(0xFFE21B00),
                const Color(0xFF0077DC),
                const Color(0xFF8B00DB),
                const Color(0xFF3AB000),
                const Color(0xFFFAC800),
                const Color(0xFFFA6A00),
                Colors.black,
                Colors.white,
              ].map<Widget>((color) {
                return buildColorButton(color);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildColorButton(Color color) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: SizedBox(
        width: 24,
        height: 24,
        child: ElevatedButton(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(color),
            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: color == Colors.white ? Colors.black : Colors.white, width: 1)
              ),
            ),
            elevation: MaterialStateProperty.all(0),
          ),
          child: Container(),
          onPressed: () {
            setState(() {
              _selectedColor = color;
              _text?.color = color;
            });
          },
        ),
      ),
    );
  }

  Widget buildSaveButton() {
    return GestureDetector(
      onTap: _isDrawText ? _submitText : _save,
      child: const CircleAvatar(
        backgroundColor: APP_UI_COLOR_ACCENT,
        child: Icon(
          Icons.check_rounded,
          size: 24.0,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget buildUndoButton() {
    return _lines.isEmpty ? const SizedBox() : GestureDetector(
      onTap: _undo,
      child: const CircleAvatar(
        radius: 16,
        backgroundColor: APP_UI_COLOR_INFO,
        child: Icon(
          Icons.undo_rounded,
          size: 20.0,
          color: Colors.white,
        ),
      ),
    );
  }
  
  Widget buildClearButton() {
    return _lines.isEmpty ? const SizedBox() : GestureDetector(
      onTap: _clear,
      child: const CircleAvatar(
        radius: 16,
        backgroundColor: APP_UI_COLOR_INFO,
        child: Icon(
          Icons.restore_rounded,
          size: 20.0,
          color: Colors.white,
        ),
      ),
    );
  }
}

class AddText extends StatefulWidget {
  const AddText(this.text, { Key? key }) : super(key: key);
  final DrawnText? text;

  @override
  State<AddText> createState() => _AddTextState();
}

class _AddTextState extends State<AddText> {
  final _textController = TextEditingController();

  @override
  void initState() {
    _textController.text = widget.text?.text ?? '';
    super.initState();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  _submit(val) => Navigator.pop(context, val);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: const InputDecoration(hintText: 'Write text'),
          controller: _textController,
          onSubmitted: _submit,
        ),
        const SizedBox(height: 12,),
        Row(
          children: [
            ElevatedButton(child: const Text("Submit"), onPressed: () => _submit(_textController.text),),
            const SizedBox(width: 12,),
            ElevatedButton(onPressed: Navigator.of(context).pop, child: const Text("Cancel"),),
          ],
        ),
      ],
    );
  }
}