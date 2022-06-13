import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

final _fToast = FToast();

class MyHelper {
  final BuildContext context;
  MyHelper(this.context) {
    _fToast.init(context);
  }

  Future showDialog({
    DialogType type = DialogType.NO_HEADER,
    String? title,
    String? message,
    Widget? body,
    VoidCallback? onCancel,
    VoidCallback? onOK,
  }) {
    final dialog = AwesomeDialog(
      context: context,
      animType: AnimType.SCALE,
      dialogType: type,
      body: body == null ? null : Container(padding: const EdgeInsets.all(20), alignment: Alignment.center, child: body,),
      title: title,
      desc: message,
      btnCancelOnPress: onCancel,
      btnOkOnPress: onOK,
    );
    return dialog.show();
  }

  Future<bool> showConfirmDialog(String message, {String? title}) async {
    return await showDialog(
      type: DialogType.QUESTION,
      title: title,
      message: message,
      onOK: () => Navigator.pop(context, true),
    ) ?? false;
  }

  showToast(String message) {
    Widget toast = Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(25.0),
      color: Colors.greenAccent,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check),
          const SizedBox(width: 12.0,),
          Expanded(child: Text(message)),
        ],
      ),
    );

    _fToast.showToast(
      child: toast,
      gravity: ToastGravity.BOTTOM,
      toastDuration: const Duration(seconds: 3),
    );
  }

  Future<Directory> getDownloadDirectory() async {
    late final Directory dir;
    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download');
      final downloadDirExist = await downloadDir.exists();
      dir = downloadDirExist ? downloadDir : (await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory());
    } else if (Platform.isIOS) {
      dir = await getApplicationDocumentsDirectory();
    }
    return await Directory('${dir.path}/Drawie').create(recursive: true);
  }

  Future<String> getDownloadPath(String fileName) async {
    return '${(await getDownloadDirectory()).path}/$fileName';
  }

  Future shareFile(String filePath, {String? title, String? message}) {
    return Share.shareFiles([filePath], subject: title, text: message);
  }
}