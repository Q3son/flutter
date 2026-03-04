// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'project.dart';

// Reproduction case from
// https://github.com/flutter/flutter/issues/161466#issuecomment-2743309718.
class HotRestartWithPausedChildIsolateProject extends Project {
  @override
<<<<<<< HEAD
  final String pubspec = '''
=======
  final pubspec = '''
>>>>>>> 48c32af0345e9ad5747f78ddce828c7f795f7159
  name: test
  environment:
    sdk: ^3.7.0-0

  dependencies:
    flutter:
      sdk: flutter
  ''';

  @override
<<<<<<< HEAD
  final String main = r'''
=======
  final main = r'''
>>>>>>> 48c32af0345e9ad5747f78ddce828c7f795f7159
  import 'dart:async';
  import 'dart:developer';
  import 'dart:isolate';

  import 'package:flutter/material.dart';

  void main() {
    WidgetsFlutterBinding.ensureInitialized().platformDispatcher.onError = (Object error, StackTrace? stack) {
      print('HERE');
      return true;
    };
    runApp(
      const Center(
        child: Text(
          'Hello, world!',
          key: Key('title'),
          textDirection: TextDirection.ltr,
        ),
      ),
    );

    Isolate.run(() {
      print('COMPUTING');
      debugger();
    });
  }
  ''';
}
