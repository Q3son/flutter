// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.app;

import android.app.Application;

/**
 * Empty implementation of the {@link Application} class, provided to avoid breaking older Flutter
 * projects. Flutter projects which need to extend an Application should migrate to extending {@link
 * android.app.Application} instead.
 *
<<<<<<< HEAD
 * <p>For more information on the removal of Flutter's v1 Android embedding, see:
 * https://docs.flutter.dev/release/breaking-changes/v1-android-embedding.
=======
 * <p>For more information on the removal of Flutter's v1 Android embedding, see: <a
 * href="https://docs.flutter.dev/release/breaking-changes/v1-android-embedding">https://docs.flutter.dev/release/breaking-changes/v1-android-embedding</a>.
>>>>>>> 48c32af0345e9ad5747f78ddce828c7f795f7159
 */
@Deprecated
public class FlutterApplication extends Application {}
