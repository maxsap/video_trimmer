import 'dart:io';

import 'package:example/preview.dart';
import 'package:flutter/material.dart';
import 'package:video_trimmer/video_trimmer.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:video_trimmer/src/processing_result.dart';

class TrimmerView extends StatefulWidget {
  final Trimmer _trimmer;
  TrimmerView(this._trimmer);
  @override
  _TrimmerViewState createState() => _TrimmerViewState();
}

class _TrimmerViewState extends State<TrimmerView> {
  double _startValue = 0.0;
  double _endValue = 0.0;

  bool _isPlaying = false;
  bool _progressVisibility = false;

  Future<ProcessingResult> _saveVideo() async {
    setState(() {
      _progressVisibility = true;
    });

    ProcessingResult _processingResult;

    // final File watermarkFile = await _getPath();
    // final String watermarkPath = watermarkFile.path;
    // String addWatermark =
    //     '-ignore_loop 0 -i "$watermarkPath" -filter_complex "overlay=x=(main_w-overlay_w):y=(main_h-overlay_h)" -c:a copy';
    // final String overlayCommand = '''
    // -filter_complex "[0]split[v0][v1];[v0]crop=iw:ih/2,format=rgba,geq=r=0:g=0:b=0:a=255*(Y/H)[fg];[v1][fg]overlay=0:H-h:format=auto"
    // ''';
    final File fontPath = await _getFontPath();
    final String path = fontPath.path;
    final String waterMarkString = '''
    -vf "drawtext=text='Text':x=10:y=H-th-10:fontfile=$path:fontsize=32:fontcolor=white:shadowcolor=black:shadowx=5:shadowy=5"
    ''';

    // final String waterMarkString = '''
    // ''';

    await widget._trimmer
        .saveTrimmedVideo(
      startValue: _startValue,
      endValue: _endValue,
      ffmpegCommand: waterMarkString,
    )
        .then((value) {
      setState(() {
        _progressVisibility = false;
        _processingResult = value;
      });
    });

    return _processingResult;
  }

  Future<File> _getPath() async {
    Directory directory = await getApplicationDocumentsDirectory();
    var dbPath = join(directory.path, "watermark.gif");
    ByteData data = await rootBundle.load("assets/watermark2.gif");
    List<int> bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    return File(dbPath).writeAsBytes(bytes);
  }

  Future<File> _getFontPath() async {
    Directory directory = await getApplicationDocumentsDirectory();
    var dbPath = join(directory.path, "FreeSans.ttf");
    ByteData data = await rootBundle.load("assets/FreeSans.ttf");
    List<int> bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    return File(dbPath).writeAsBytes(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Video Trimmer"),
      ),
      body: Builder(
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.only(bottom: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                Visibility(
                  visible: _progressVisibility,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.red,
                  ),
                ),
                RaisedButton(
                  onPressed: _progressVisibility
                      ? null
                      : () async {
                          _saveVideo().then((ProcessingResult outputPath) {
                            print('OUTPUT PATH: $outputPath');
                            final snackBar = SnackBar(
                              content: Text('Video Saved successfully'),
                            );
                            Scaffold.of(context).showSnackBar(snackBar);
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) =>
                                    Preview(outputPath.outputPath),
                              ),
                            );
                          });
                        },
                  child: Text("SAVE"),
                ),
                Expanded(
                  child: VideoViewer(),
                ),
                Center(
                  child: TrimEditor(
                    viewerHeight: 50.0,
                    viewerWidth: MediaQuery.of(context).size.width,
                    maxDuration: Duration(seconds: 30),
                    minDuration: Duration(seconds: 5),
                    // fit: BoxFit.cover,
                    onChangeStart: (value) {
                      _startValue = value;
                    },
                    onChangeEnd: (value) {
                      _endValue = value;
                    },
                    onChangePlaybackState: (value) {
                      setState(() {
                        _isPlaying = value;
                      });
                    },
                  ),
                ),
                FlatButton(
                  child: _isPlaying
                      ? Icon(
                          Icons.pause,
                          size: 80.0,
                          color: Colors.white,
                        )
                      : Icon(
                          Icons.play_arrow,
                          size: 80.0,
                          color: Colors.white,
                        ),
                  onPressed: () async {
                    bool playbackState =
                        await widget._trimmer.videPlaybackControl(
                      startValue: _startValue,
                      endValue: _endValue,
                    );
                    setState(() {
                      _isPlaying = playbackState;
                    });
                  },
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
