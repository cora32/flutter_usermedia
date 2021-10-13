@JS() // Sets the context, which in this case is `window`
library custom;

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui' as ui;
import 'package:js/js.dart';

import 'package:flutter/material.dart';

import 'consts.dart';


@JS()
external void detectFace(dynamic rgba);

class CameraTest extends StatefulWidget {
  final bool enableAudio;

  const CameraTest({Key? key, this.enableAudio = enableAudioC})
      : super(key: key);

  @override
  _CameraTestState createState() => _CameraTestState();
}

class _CameraTestState extends State<CameraTest> {
  final _vcvCameraController = VCVCameraController();
  var hasFace = false;
  var errors = <String>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              children: [
                const Text('217'),
                RaisedButton(
                  child: Text('Next'),
                  onPressed: () {
                    _vcvCameraController.reset();
                  },
                ),
                RaisedButton(
                  child: Text('Start recording'),
                  onPressed: () {
                    _vcvCameraController.start();
                  },
                ),
                RaisedButton(
                  child: Text('Stop recording'),
                  onPressed: () {
                    _vcvCameraController.stop();
                  },
                ),
                RaisedButton(
                  child: Text('Check face'),
                  onPressed: () {
                    hasFace = _vcvCameraController.hasFace();
                    setState(() {});
                  },
                ),
                Text(
                  hasFace ? 'Has face' : 'No face',
                ),
                RaisedButton(
                  child: Text('Get errors'),
                  onPressed: () {
                    errors = _vcvCameraController.getErrors();
                    print('>>> errors ${errors.length}');
                    setState(() {});
                  },
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: errors.map((e) => Text(e)).toList(),
            ),
            Container(
                constraints: const BoxConstraints(maxHeight: 680),
                child: WebCam(
                    controller: _vcvCameraController,
                    enableAudio: widget.enableAudio)),
          ],
        ),
      ),
    );
  }
}

class VCVCameraController {
  late _WebCamState state;
  Function(bool)? _onFaceStateChanged;

  void setOnFaceChanged(Function(bool) onFaceStateChanged) {
    _onFaceStateChanged = onFaceStateChanged;
  }

  void _setup(_WebCamState state) {
    this.state = state;
  }

  void reset() {
    state._reset();
  }

  void start({VoidCallback? onCallback}) {
    state._start(onCallback: onCallback);
  }

  void stop() {
    state._stop();
  }

  List<String> getErrors() {
    return state.getErrors();
  }

  String getUrl() => state._currentUrl;

  bool hasFace() => state._hasFace();
}

class WebCam extends StatefulWidget {
  final VCVCameraController controller;
  final bool enableAudio;

  const WebCam(
      {Key? key,
      required this.controller,
      this.enableAudio = enableAudioC})
      : super(key: key);

  @override
  _WebCamState createState() => _WebCamState();
}

class _WebCamState extends State<WebCam> {
  final html.VideoElement _webcamVideoElement = html.VideoElement();
  final html.VideoElement _webcamVideoElementForIosBecauseItsTooSpecial =
      html.VideoElement();
  final html.CanvasElement _canvasElement = html.CanvasElement(
      width: videoWidth.toInt(),
      height: videoHeight.toInt());
  html.MediaRecorder? recorder;
  html.MediaStream? _latestStreamHandler;
  var _currentUrl = '';
  var recordedChunks = <html.Blob?>[];
  var errors = <String>[];
  var hasFace = false;
  var showIosPreview = false;
  var startupError = '';

  late Timer _timer;

  final _key = UniqueKey();
  final _iosPreviewKey = UniqueKey();

  // final _canvasKey = UniqueKey();

  @override
  void initState() {
    super.initState();

    widget.controller._setup(this);

    // Register a webcam
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory('webcamVideoElement',
        (int viewId) {
      switchCameraOn();
      loadPico();
      return _webcamVideoElement;
    });
    // Register a video preview specially for safari because it cannot
    // reuse video tag with both src and srcObject
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
        'webcamVideoElementForIosBecauseItsTooSpecial', (int viewId) {
      return _webcamVideoElementForIosBecauseItsTooSpecial;
    });
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory('canvasElement', (int viewId) {
      return _canvasElement;
    });

    _timer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (widget.controller._onFaceStateChanged == null) return;

      final _currentFaceState = _hasFace();

      // if(hasFace != _currentFaceState) {
      hasFace = _currentFaceState;
      widget.controller._onFaceStateChanged!.call(hasFace);
      // }
    });
  }

  @override
  void dispose() {
    switchCameraOff();
    _timer.cancel();

    super.dispose();
  }

  void startVideo(html.MediaStream stream) {
    _webcamVideoElementForIosBecauseItsTooSpecial.pause();

    _webcamVideoElement
      ..load()
      ..srcObject = null
      ..removeAttribute('srcObject')
      ..srcObject = stream
      ..controls = false
      ..loop = true
      ..autoplay = true
      ..muted = true
      ..setAttribute('disablepictureinpicture', 'true')..setAttribute('controlslist', 'nodownload')..setAttribute('playsinline', 'true')
      ..play();
  }

  void previewVideo() {
    _webcamVideoElement.pause();

    final blob = html.Blob(recordedChunks, 'video/mp4');
    errors.add('recordedChunks size: ${recordedChunks.length}');
    _currentUrl = html.Url.createObjectUrlFromBlob(blob);
    errors.add('_currentUrl: $_currentUrl');

    // _webcamVideoElement
    //   ..controls = false
    //   ..loop = true
    //   ..autoplay = true
    //   ..muted = true
    //   ..setAttribute('disablepictureinpicture', 'true')
    //   ..setAttribute('controlslist', 'nodownload')
    //   ..setAttribute('playsinline', 'true')
    //   ..src = _currentUrl
    //   ..controls = true
    //   ..loop = true
    //   ..autoplay = true
    //   ..muted = false
    //   ..setAttribute('disablepictureinpicture', 'true')
    //   ..setAttribute('controlslist', 'nodownload')
    //   ..setAttribute('playsinline', 'true')
    //   // ..currentTime = 0
    //   ..load()
    //   ..play();

    _webcamVideoElementForIosBecauseItsTooSpecial
      ..load()
      ..src = _currentUrl
      ..controls = true
      ..loop = true
      ..autoplay = true
      ..muted = false
      ..setAttribute('disablepictureinpicture', 'true')
      ..setAttribute('controlslist', 'nodownload')
      ..setAttribute('playsinline', 'true')
      ..play();
  }

  switchCameraOff() {
    if (_webcamVideoElement.srcObject != null &&
        (_webcamVideoElement.srcObject?.active ?? false)) {
      _webcamVideoElement
        ..srcObject?.getTracks().forEach((track) {
          track.stop();
        })
        ..srcObject = null
        ..removeAttribute('srcObject');
    } else {
      errors.add('Failed to switch CameraOff');
      print('>>>> Failed to switch CameraOff');
    }
  }

  void switchCameraOn({Function(html.MediaRecorder)? onReady}) {
    html.window.navigator.mediaDevices?.getUserMedia({
      'video': {
        'height': videoHeight,
        'width': videoWidth,
        'facingMode': 'user',
        'frameRate': 15
      },
      'audio': enableAudioC,
    }).then((streamHandle) {
      _latestStreamHandler = streamHandle;

      startVideo(streamHandle);

      recorder = setupRecorder(streamHandle);

      onReady?.call(recorder!);
    }).catchError((onError) {
      errors.add('$onError');
      print(onError);

      setState(() {
        startupError = '$onError';
      });
    });
  }

  html.MediaRecorder setupRecorder(html.MediaStream streamHandle) {
    return html.MediaRecorder(streamHandle, {
      // 'audioBitsPerSecond': mimeType,
      'videoBitsPerSecond': 400 * 1000
    })
      ..addEventListener('dataavailable', (event) {
        errors.add('dataavailable event: $event');

        if (event is html.BlobEvent) {
          final data = event.data;
          recordedChunks.add(data!);
        }
      }, false)
      ..addEventListener('stop', (event) {
        errors.add('stop event');
        previewVideo();
      }, false);
  }

  @override
  Widget build(BuildContext context) {
    return startupError.isEmpty
        ? Stack(
            children: [
              HtmlElementView(
                key: _key,
                viewType: 'webcamVideoElement',
              ),
              Opacity(
                opacity: showIosPreview ? 1 : 0,
                child: HtmlElementView(
                  key: _iosPreviewKey,
                  viewType: 'webcamVideoElementForIosBecauseItsTooSpecial',
                ),
              ),
            ],
          )
        : Center(child: Text(startupError));
    // return startupError.isEmpty
    //     ? (showIosPreview
    //         ? HtmlElementView(
    //             key: _iosPreviewKey,
    //             viewType: 'webcamVideoElementForIosBecauseItsTooSpecial',
    //           )
    //         : HtmlElementView(
    //             key: _key,
    //             viewType: 'webcamVideoElement',
    //           ))
    //     : Center(child: Text(startupError));
    // return Column(
    //   children: [
    //     Container(
    //       height: 240,
    //       child: HtmlElementView(
    //         key: _key,
    //         viewType: 'webcamVideoElement',
    //       ),
    //     ),
    //     Container(
    //       height: 440,
    //       child: HtmlElementView(
    //         key: _iosPreviewKey,
    //         viewType: 'webcamVideoElementForIosBecauseItsTooSpecial',
    //       ),
    //     ),
    //   ],
    // );
  }

  void _reset() {
    setState(() {
      showIosPreview = false;
      startupError = '';
    });

    if (_latestStreamHandler == null) {
      switchCameraOn();
    } else {
      startVideo(_latestStreamHandler!);
    }
  }

  void _start({VoidCallback? onCallback}) {
    setState(() {
      showIosPreview = false;
      startupError = '';
    });

    if (recorder == null || recorder!.state == 'inactive') {
      recordedChunks.clear();
      // onCallback?.call();

      switchCameraOn(onReady: (recorder) {
        recorder.start();
      });
    } else {
      print('>>>> already started, recorder.state: ${recorder?.state}');
      errors.add('already started, recorder.state: ${recorder?.state}');
    }
  }

  void _stop() {
    setState(() {
      showIosPreview = true;
    });

    if (recorder?.state != 'inactive') {
      recorder?.stop();
    } else {
      print('>>>> already stopped, recorder.state: ${recorder?.state}');
      errors.add('already stopped, recorder.state: ${recorder?.state}');
    }
  }

  _hasFace() {
    // js.context.callMethod('detectFace', [_canvasElement.context2D, _webcamVideoElement]);
    _canvasElement.context2D.drawImage(_webcamVideoElement, 0, 0);
    final imageData = _canvasElement.context2D.getImageData(
        0, 0, videoWidth.toInt(), videoHeight.toInt());

    detectFace(imageData.data);

    var state = js.JsObject.fromBrowserObject(js.context['state']);
    final bool hasFace = state['hasFace'];

    return hasFace;
  }

  void loadPico() {
    js.context.callMethod('loadPico');
  }

  List<String> getErrors() => errors;
}
