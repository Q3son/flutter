// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:ui/src/engine.dart';
import 'package:ui/ui.dart' as ui;

// Only supported in profile/release mode. Allows Flutter to use MSAA but
// removes the ability for disabling AA on Paint objects.
const bool _kUsingMSAA = bool.fromEnvironment('flutter.canvaskit.msaa');

/// The base class for CanvasKit surfaces, containing shared logic for context
/// management and Skia object creation.
abstract class CkSurface extends Surface {
  CkSurface(this._canvasProvider) {
    _canvas = _canvasProvider.acquireCanvas(_currentSize, onContextLost: onContextLost);
    _maybeAttachCanvasToDom();
    _initialize();
  }

  final CanvasProvider _canvasProvider;

  BitmapSize _currentSize = const BitmapSize(1, 1);

  /// The underlying Skia surface object.
  SkSurface? get skSurface => _skSurface;
  SkSurface? _skSurface;

  /// Whether or not WebGl is supported.
  ///
  /// This defaults to true unless `canvasKitForceCpuOnly` is set to true or
  /// `webGLVersion` is -1. If Skia fails to create a GrContext, this will be
  /// set to false.
  @visibleForTesting
  bool get supportsWebGl {
    if (configuration.canvasKitForceCpuOnly) {
      _fallbackToSoftwareReason = 'canvasKitForceCpuOnly is set to true';
      return false;
    }
<<<<<<< HEAD
    return submitCallback(this, skiaCanvas);
  }

  CkCanvas get skiaCanvas => skiaSurface.getCanvas();
}

/// A surface which can be drawn into by the compositor.
///
/// The underlying representation is a [CkSurface], which can be reused by
/// successive frames if they are the same size. Otherwise, a new [CkSurface] is
/// created.
class Surface extends DisplayCanvas {
  Surface({this.isDisplayCanvas = false})
    : useOffscreenCanvas = Surface.offscreenCanvasSupported && !isDisplayCanvas;

  CkSurface? _surface;

  /// Whether or not to use an `OffscreenCanvas` to back this [Surface].
  final bool useOffscreenCanvas;

  /// If `true`, this [Surface] is used as a [DisplayCanvas].
  final bool isDisplayCanvas;

  /// If true, forces a new WebGL context to be created, even if the window
  /// size is the same. This is used to restore the UI after the browser tab
  /// goes dormant and loses the GL context.
  bool _forceNewContext = true;
  bool get debugForceNewContext => _forceNewContext;

  bool _contextLost = false;
  bool get debugContextLost => _contextLost;

  /// Forces AssertionError when attempting to create a CPU-based surface.
  /// Only for tests.
  bool debugThrowOnSoftwareSurfaceCreation = false;

  /// A cached copy of the most recently created `webglcontextlost` listener.
  ///
  /// We must cache this function because each time we access the tear-off it
  /// creates a new object, meaning we won't be able to remove this listener
  /// later.
  DomEventListener? _cachedContextLostListener;

  /// A cached copy of the most recently created `webglcontextrestored`
  /// listener.
  ///
  /// We must cache this function because each time we access the tear-off it
  /// creates a new object, meaning we won't be able to remove this listener
  /// later.
  DomEventListener? _cachedContextRestoredListener;

  SkGrContext? _grContext;
  int? _glContext;
  int? _skiaCacheBytes;

  /// The underlying OffscreenCanvas element used for this surface.
  DomOffscreenCanvas? _offscreenCanvas;

  /// Returns the underlying OffscreenCanvas. Should only be used in tests.
  DomOffscreenCanvas? debugGetOffscreenCanvas() {
    bool assertsEnabled = false;
    assert(() {
      assertsEnabled = true;
      return true;
    }());
    if (!assertsEnabled) {
      throw StateError('debugGetOffscreenCanvas() can only be used in tests');
    }
    return _offscreenCanvas;
  }

  /// The <canvas> backing this Surface in the case that OffscreenCanvas isn't
  /// supported.
  DomCanvasElement? _canvasElement;

  /// Note, if this getter is called, then this Surface is being used as an
  /// overlay and must be backed by an onscreen <canvas> element.
  @override
  final DomElement hostElement = createDomElement('flt-canvas-container');

  int _pixelWidth = -1;
  int _pixelHeight = -1;
  double _currentDevicePixelRatio = -1;
  int _sampleCount = -1;
  int _stencilBits = -1;

  /// Specify the GPU resource cache limits.
  void setSkiaResourceCacheMaxBytes(int bytes) {
    _skiaCacheBytes = bytes;
    _syncCacheBytes();
  }

  void _syncCacheBytes() {
    if (_skiaCacheBytes != null) {
      _grContext?.setResourceCacheLimitBytes(_skiaCacheBytes!.toDouble());
    }
  }

  /// The CanvasKit canvas associated with this surface.
  CkCanvas getCanvas() {
    return _surface!.getCanvas();
  }

  void flush() {
    _surface!.flush();
  }

  Future<void> rasterizeToCanvas(
    BitmapSize bitmapSize,
    RenderCanvas canvas,
    List<CkPicture> pictures,
  ) async {
    final CkCanvas skCanvas = getCanvas();
    skCanvas.clear(const ui.Color(0x00000000));
    pictures.forEach(skCanvas.drawPicture);
    flush();

    if (browserSupportsCreateImageBitmap) {
      JSObject bitmapSource;
      DomImageBitmap bitmap;
      if (useOffscreenCanvas) {
        bitmap = _offscreenCanvas!.transferToImageBitmap();
      } else {
        bitmapSource = _canvasElement! as JSObject;
        bitmap = await createImageBitmap(bitmapSource, (
          x: 0,
          y: _pixelHeight - bitmapSize.height,
          width: bitmapSize.width,
          height: bitmapSize.height,
        ));
      }
      canvas.render(bitmap);
    } else {
      // If the browser doesn't support `createImageBitmap` (e.g. Safari 14)
      // then render using `drawImage` instead.
      DomCanvasImageSource imageSource;
      if (useOffscreenCanvas) {
        imageSource = _offscreenCanvas! as DomCanvasImageSource;
      } else {
        imageSource = _canvasElement! as DomCanvasImageSource;
      }
      canvas.renderWithNoBitmapSupport(imageSource, _pixelHeight, bitmapSize);
    }
  }

  /// Acquire a frame of the given [size] containing a drawable canvas.
  ///
  /// The given [size] is in physical pixels.
  SurfaceFrame acquireFrame(ui.Size size) {
    final CkSurface surface = createOrUpdateSurface(BitmapSize.fromSize(size));

    // ignore: prefer_function_declarations_over_variables
    final SubmitCallback submitCallback = (SurfaceFrame surfaceFrame, CkCanvas canvas) {
      return _presentSurface();
    };

    return SurfaceFrame(surface, submitCallback);
  }

  BitmapSize? _currentCanvasPhysicalSize;

  /// Sets the CSS size of the canvas so that canvas pixels are 1:1 with device
  /// pixels.
  void _updateLogicalHtmlCanvasSize() {
    final double devicePixelRatio = EngineFlutterDisplay.instance.devicePixelRatio;
    final double logicalWidth = _pixelWidth / devicePixelRatio;
    final double logicalHeight = _pixelHeight / devicePixelRatio;
    final DomCSSStyleDeclaration style = _canvasElement!.style;
    style.width = '${logicalWidth}px';
    style.height = '${logicalHeight}px';
    _currentDevicePixelRatio = devicePixelRatio;
  }

  /// The <canvas> element backing this surface may be larger than the screen.
  /// The Surface will draw the frame to the bottom left of the <canvas>, but
  /// the <canvas> is, by default, positioned so that the top left corner is in
  /// the top left of the window. We need to shift the canvas down so that the
  /// bottom left of the <canvas> is the the bottom left corner of the window.
  void positionToShowFrame(BitmapSize frameSize) {
    assert(isDisplayCanvas, 'Should not position Surface if not used as a render canvas');
    final double devicePixelRatio = EngineFlutterDisplay.instance.devicePixelRatio;
    final double logicalHeight = _pixelHeight / devicePixelRatio;
    final double logicalFrameHeight = frameSize.height / devicePixelRatio;

    // Shift the canvas up so the bottom left is in the window.
    _canvasElement!.style.transform = 'translate(0px, ${logicalFrameHeight - logicalHeight}px)';
  }

  /// This is only valid after the first frame or if [ensureSurface] has been
  /// called
  bool get usingSoftwareBackend =>
      _glContext == null ||
      _grContext == null ||
      webGLVersion == -1 ||
      configuration.canvasKitForceCpuOnly;

  /// Ensure that the initial surface exists and has a size of at least [size].
  ///
  /// If not provided, [size] defaults to 1x1.
  ///
  /// This also ensures that the gl/grcontext have been populated so
  /// that software rendering can be detected.
  void ensureSurface([BitmapSize size = const BitmapSize(1, 1)]) {
    // If the GrContext hasn't been setup yet then we need to force initialization
    // of the canvas and initial surface.
    if (_surface != null) {
      return;
    }
    // TODO(jonahwilliams): this is somewhat wasteful. We should probably
    // eagerly setup this surface instead of delaying until the first frame?
    // Or at least cache the estimated window size.
    // This is the first frame we have rendered with this canvas.
    createOrUpdateSurface(size);
  }

  /// Creates a <canvas> and SkSurface for the given [size].
  CkSurface createOrUpdateSurface(BitmapSize size) {
    if (size.isEmpty) {
      throw CanvasKitError('Cannot create surfaces of empty size.');
    }

    if (!_forceNewContext) {
      // Check if the window is the same size as before, and if so, don't allocate
      // a new canvas as the previous canvas is big enough to fit everything.
      final BitmapSize? previousSurfaceSize = _surface?._size;
      if (previousSurfaceSize != null &&
          size.width == previousSurfaceSize.width &&
          size.height == previousSurfaceSize.height) {
        final double devicePixelRatio = EngineFlutterDisplay.instance.devicePixelRatio;
        if (isDisplayCanvas && devicePixelRatio != _currentDevicePixelRatio) {
          _updateLogicalHtmlCanvasSize();
        }
        return _surface!;
      }

      if (_currentCanvasPhysicalSize != null &&
          (size.width != _currentCanvasPhysicalSize!.width ||
              size.height != _currentCanvasPhysicalSize!.height)) {
        _surface?.dispose();
        _surface = null;
        _pixelWidth = size.width;
        _pixelHeight = size.height;
        if (useOffscreenCanvas) {
          _offscreenCanvas!.width = _pixelWidth.toDouble();
          _offscreenCanvas!.height = _pixelHeight.toDouble();
        } else {
          _canvasElement!.width = _pixelWidth.toDouble();
          _canvasElement!.height = _pixelHeight.toDouble();
        }
        _currentCanvasPhysicalSize = BitmapSize(_pixelWidth, _pixelHeight);
        if (isDisplayCanvas) {
          _updateLogicalHtmlCanvasSize();
        }
      }
    }

    // If we reached here, then either we are forcing a new context, or
    // the size of the surface has changed so we need to make a new one.

    _surface?.dispose();
    _surface = null;

    // Either a new context is being forced or we've never had one.
    if (_forceNewContext || _currentCanvasPhysicalSize == null) {
      _grContext?.releaseResourcesAndAbandonContext();
      _grContext?.delete();
      _grContext = null;

      _createNewCanvas(size);
      _currentCanvasPhysicalSize = size;
    }

    return _surface = _createNewSurface(size);
  }

  JSVoid _contextRestoredListener(DomEvent event) {
    assert(
      _contextLost,
      'Received "webglcontextrestored" event but never received '
      'a "webglcontextlost" event.',
    );
    _contextLost = false;
    // Force the framework to rerender the frame.
    EnginePlatformDispatcher.instance.invokeOnMetricsChanged();
    event.stopPropagation();
    event.preventDefault();
  }

  JSVoid _contextLostListener(DomEvent event) {
    assert(
      event.target == _offscreenCanvas || event.target == _canvasElement,
      'Received a context lost event for a disposed canvas',
    );
    _contextLost = true;
    _forceNewContext = true;
    event.preventDefault();
  }

  /// This function is expensive.
  ///
  /// It's better to reuse canvas if possible.
  void _createNewCanvas(BitmapSize physicalSize) {
    // Clear the container, if it's not empty. We're going to create a new <canvas>.
    if (_offscreenCanvas != null) {
      _offscreenCanvas!.removeEventListener(
        'webglcontextrestored',
        _cachedContextRestoredListener,
        false,
      );
      _offscreenCanvas!.removeEventListener('webglcontextlost', _cachedContextLostListener, false);
      _offscreenCanvas = null;
      _cachedContextRestoredListener = null;
      _cachedContextLostListener = null;
    } else if (_canvasElement != null) {
      _canvasElement!.removeEventListener(
        'webglcontextrestored',
        _cachedContextRestoredListener,
        false,
      );
      _canvasElement!.removeEventListener('webglcontextlost', _cachedContextLostListener, false);
      _canvasElement!.remove();
      _canvasElement = null;
      _cachedContextRestoredListener = null;
      _cachedContextLostListener = null;
    }

    // If `physicalSize` is not precise, use a slightly bigger canvas. This way
    // we ensure that the rendred picture covers the entire browser window.
    _pixelWidth = physicalSize.width;
    _pixelHeight = physicalSize.height;
    DomEventTarget htmlCanvas;
    if (useOffscreenCanvas) {
      final DomOffscreenCanvas offscreenCanvas = createDomOffscreenCanvas(
        _pixelWidth,
        _pixelHeight,
      );
      htmlCanvas = offscreenCanvas;
      _offscreenCanvas = offscreenCanvas;
      _canvasElement = null;
    } else {
      final DomCanvasElement canvas = createDomCanvasElement(
        width: _pixelWidth,
        height: _pixelHeight,
      );
      htmlCanvas = canvas;
      _canvasElement = canvas;
      _offscreenCanvas = null;
      if (isDisplayCanvas) {
        _canvasElement!.setAttribute('aria-hidden', 'true');
        _canvasElement!.style.position = 'absolute';
        hostElement.append(_canvasElement!);
        _updateLogicalHtmlCanvasSize();
      }
    }

    // When the browser tab using WebGL goes dormant the browser and/or OS may
    // decide to clear GPU resources to let other tabs/programs use the GPU.
    // When this happens, the browser sends the "webglcontextlost" event as a
    // notification. When we receive this notification we force a new context.
    //
    // See also: https://www.khronos.org/webgl/wiki/HandlingContextLost
    _cachedContextRestoredListener = createDomEventListener(_contextRestoredListener);
    _cachedContextLostListener = createDomEventListener(_contextLostListener);
    htmlCanvas.addEventListener('webglcontextlost', _cachedContextLostListener, false);
    htmlCanvas.addEventListener('webglcontextrestored', _cachedContextRestoredListener, false);
    _forceNewContext = false;
    _contextLost = false;

    if (webGLVersion != -1 && !configuration.canvasKitForceCpuOnly) {
      int glContext = 0;
      final SkWebGLContextOptions options = SkWebGLContextOptions(
        // Default to no anti-aliasing. Paint commands can be explicitly
        // anti-aliased by setting their `Paint` object's `antialias` property.
        antialias: _kUsingMSAA ? 1 : 0,
        majorVersion: webGLVersion.toDouble(),
      );
      if (useOffscreenCanvas) {
        glContext = canvasKit.GetOffscreenWebGLContext(_offscreenCanvas!, options).toInt();
      } else {
        glContext = canvasKit.GetWebGLContext(_canvasElement!, options).toInt();
      }

      _glContext = glContext;

      if (_glContext != 0) {
        _grContext = canvasKit.MakeGrContext(glContext.toDouble());
        if (_grContext == null) {
          throw CanvasKitError(
            'Failed to initialize CanvasKit. '
            'CanvasKit.MakeGrContext returned null.',
          );
        }
        if (_sampleCount == -1 || _stencilBits == -1) {
          _initWebglParams();
        }
        // Set the cache byte limit for this grContext, if not specified it will
        // use CanvasKit's default.
        _syncCacheBytes();
      }
    }
  }

  void _initWebglParams() {
    WebGLContext gl;
    if (useOffscreenCanvas) {
      gl = _offscreenCanvas!.getGlContext(webGLVersion);
    } else {
      gl = _canvasElement!.getGlContext(webGLVersion);
    }
    _sampleCount = gl.getParameter(gl.samples);
    _stencilBits = gl.getParameter(gl.stencilBits);
  }

  CkSurface _createNewSurface(BitmapSize size) {
    assert(_offscreenCanvas != null || _canvasElement != null);
=======
>>>>>>> 48c32af0345e9ad5747f78ddce828c7f795f7159
    if (webGLVersion == -1) {
      _fallbackToSoftwareReason = 'webGLVersion is -1';
      return false;
    }
    if (_failedToCreateGrContext) {
      return false;
    }
    return true;
  }

  String? _fallbackToSoftwareReason;

  /// When true, the surface will fail to create a GL context and fall back to
  /// software rendering. This is useful for testing.
  @visibleForTesting
  static bool debugForceGLFailure = false;

  bool _failedToCreateGrContext = false;

  static bool _didWarnAboutWebGlInitializationFailure = false;

  /// The underlying GL context. Returns -1 if the context is not initialized.
  @override
  @visibleForTesting
  int get glContext => _glContext;
  int _glContext = -1;

  /// The canvas object that this surface is rendering to.
  @visibleForTesting
  DomEventTarget get canvas => _canvas;
  late DomEventTarget _canvas;

  void _maybeAttachCanvasToDom();

  /// A [Future] which completes when the [Surface] is initialized and ready to
  /// render pictures.
  @override
  Future<void> get initialized => _initialized.future;
  final Completer<void> _initialized = Completer<void>();

  late Completer<void>? _handledContextLostEvent;

  /// Creates the canvas object and initializes the graphics context.
  Future<void> _initialize() async {
    _createSkiaObjects();
    _initialized.complete();
  }

  /// The underlying Skia graphics context.
  SkGrContext? _grContext;

  /// Handles the context lost event by acquiring a new canvas and recreating
  /// the graphics context.
  void onContextLost() {
    _handledContextLostEvent?.complete();
    final DomEventTarget newCanvas = _canvasProvider.acquireCanvas(
      _currentSize,
      onContextLost: onContextLost,
    );
    recreateContextForCanvas(newCanvas);
  }

  void _recreateSkSurface() {
    if (supportsWebGl) {
      try {
        _recreateWebGlSkSurface();
      } catch (e) {
        _failedToCreateGrContext = true;
        _fallbackToSoftwareReason = 'failed to create GrContext. Error: $e';
        _recreateSoftwareSkSurface();
      }
    } else {
      _recreateSoftwareSkSurface();
    }
  }

  /// Creates the GL context and the Skia `GrContext`.
  void _createGrContext() {
    if (debugForceGLFailure) {
      _failedToCreateGrContext = true;
      _fallbackToSoftwareReason = 'debugForceGLFailure is true';
      return;
    }
    final options = SkWebGLContextOptions(
      antialias: _kUsingMSAA ? 1 : 0,
      majorVersion: webGLVersion.toDouble(),
    );
    _glContext = _getGlContext(options);
    _grContext = canvasKit.MakeGrContext(_glContext.toDouble());
    if (_grContext == null) {
      _failedToCreateGrContext = true;
      _fallbackToSoftwareReason = 'failed to create GrContext.';
    }
  }

  /// Creates the underlying GL context for the canvas.
  ///
  /// This method is implemented by subclasses to handle their specific
  /// canvas types.
  int _getGlContext(SkWebGLContextOptions options);

  /// Creates the Skia objects that are backed by the canvas.
  ///
  /// This method is responsible for creating the `SkGrContext` and the
  /// `SkSurface`.
  void _createSkiaObjects() {
    if (supportsWebGl) {
      _createGrContext();
    }
    _recreateSkSurface();
  }

  void _recreateWebGlSkSurface() {
    _skSurface?.dispose();
    _skSurface = canvasKit.MakeOnScreenGLSurface(
      _grContext!,
      _currentSize.width.toDouble(),
      _currentSize.height.toDouble(),
      SkColorSpaceSRGB,
      0,
      0,
    );
    if (_skSurface == null) {
      throw Exception('Failed to initialize CanvasKit SkSurface.');
    }
  }

  void _recreateSoftwareSkSurface() {
    if (!_didWarnAboutWebGlInitializationFailure) {
      _didWarnAboutWebGlInitializationFailure = true;
      printWarning(
        'WARNING: Falling back to CPU-only rendering. Reason: $_fallbackToSoftwareReason',
      );
    }
    _skSurface?.dispose();
    _skSurface = _createSoftwareSkSurface();
    if (_skSurface == null) {
      throw Exception('Failed to initialize CanvasKit SkSurface.');
    }
  }

  /// Creates an SkSurface for software rendering. This is used when WebGl is not
  /// supported or when it fails to initialize.
  SkSurface _createSoftwareSkSurface();

  double _currentDevicePixelRatio = -1;

  @override
  void setSize(BitmapSize size) {
    final double devicePixelRatio = EngineFlutterDisplay.instance.devicePixelRatio;
    if (_skSurface != null &&
        _currentSize == size &&
        devicePixelRatio == _currentDevicePixelRatio) {
      return;
    }
    _currentDevicePixelRatio = devicePixelRatio;
    _currentSize = size;
    _canvasProvider.resizeCanvas(canvas, size);
    _recreateSkSurface();
  }

  @override
  Future<void> recreateContextForCanvas(DomEventTarget newCanvas) async {
    // The old Skia surface is now invalid and should be disposed.
    _skSurface?.dispose();
    _skSurface = null;

    // The GrContext is also invalid and will be recreated by `_createSkiaObjects`.
    _grContext = null;

    _canvas = newCanvas;
    _maybeAttachCanvasToDom();
    _createSkiaObjects();
  }

  @override
  void dispose() {
    _skSurface?.dispose();
  }

  @override
  void setSkiaResourceCacheMaxBytes(int bytes) {
    _grContext?.setResourceCacheLimitBytes(bytes.toDouble());
  }

  @override
  Future<ByteData?> rasterizeImage(ui.Image image, ui.ImageByteFormat format) async {
    await _initialized.future;
    final ckImage = image as CkImage;
    final SkSurface skSurface = _skSurface!;
    final canvas = CkCanvas.fromSkCanvas(skSurface.getCanvas());
    canvas.drawImage(ckImage, ui.Offset.zero, ui.Paint());
    final SkImage snapshot = skSurface.makeImageSnapshot();
    final Uint8List? bytes = snapshot.encodeToBytes();
    snapshot.delete();
    return bytes?.buffer.asByteData();
  }

  @override
  DomCanvasImageSource get canvasImageSource => canvas as DomCanvasImageSource;

  @override
  Future<void> rasterizeToCanvas(ui.Picture picture) async {
    await _initialized.future;
    final canvas = CkCanvas.fromSkCanvas(_skSurface!.getCanvas());
    final ckPicture = picture as CkPicture;
    canvas.clear(const ui.Color(0x00000000));
    canvas.drawPicture(ckPicture);
    _skSurface!.flush();
  }

  @override
  Future<void> triggerContextLoss();

  @override
  Future<void> get handledContextLossEvent => _handledContextLostEvent!.future;
}

/// The CanvasKit implementation of [OffscreenSurface].
class CkOffscreenSurface extends CkSurface implements OffscreenSurface {
  CkOffscreenSurface(OffscreenCanvasProvider super.canvasProvider);

  @override
  int _getGlContext(SkWebGLContextOptions options) {
    return canvasKit.GetOffscreenWebGLContext(canvas as DomOffscreenCanvas, options).toInt();
  }

  @override
  SkSurface _createSoftwareSkSurface() {
    return canvasKit.MakeOffscreenSWCanvasSurface(canvas as DomOffscreenCanvas);
  }

  @override
  Future<List<DomImageBitmap>> rasterizeToImageBitmaps(List<ui.Picture> pictures) async {
    await _initialized.future;
    final bitmaps = <DomImageBitmap>[];
    for (final picture in pictures) {
      await rasterizeToCanvas(picture);
      bitmaps.add(await createImageBitmap(_canvas));
    }
    return bitmaps;
  }

  @override
  void _maybeAttachCanvasToDom() {
    // Do not attach the OffscreenCanvas to the DOM.
  }

  @override
  Future<void> triggerContextLoss() async {
    _handledContextLostEvent = Completer<void>();
    final WebGLContext gl = (canvas as DomOffscreenCanvas).getGlContext(webGLVersion);
    gl.loseContextExtension.loseContext();
  }
}

/// The CanvasKit implementation of [OnscreenSurface].
class CkOnscreenSurface extends CkSurface implements OnscreenSurface {
  CkOnscreenSurface(OnscreenCanvasProvider super.canvasProvider);

  @override
  int _getGlContext(SkWebGLContextOptions options) {
    return canvasKit.GetWebGLContext(canvas as DomHTMLCanvasElement, options).toInt();
  }

  @override
  SkSurface _createSoftwareSkSurface() {
    return canvasKit.MakeSWCanvasSurface(canvas as DomHTMLCanvasElement);
  }

  final DomElement _hostElement = createDomElement('flt-canvas-container');

  @override
  DomElement get hostElement => _hostElement;

  @override
  void _maybeAttachCanvasToDom() {
    hostElement.appendChild(canvas as DomHTMLCanvasElement);
  }

  @override
  bool get isConnected =>
      ((canvas as JSAny?).isA<DomHTMLCanvasElement>()) &&
      (canvas as DomHTMLCanvasElement).isConnected!;

  @override
  void initialize() {
    // No extra initialization is required.
  }

  @override
  Future<void> triggerContextLoss() async {
    _handledContextLostEvent = Completer<void>();
    final WebGLContext gl = (canvas as DomHTMLCanvasElement).getGlContext(webGLVersion);
    gl.loseContextExtension.loseContext();
  }
}
