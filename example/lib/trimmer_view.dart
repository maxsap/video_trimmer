import 'dart:io';

import 'package:example/preview.dart';
import 'package:flutter/material.dart';
import 'package:gallery_saver/gallery_saver.dart';
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

    // final File watermarkFile = await _getPath();
    // final String watermarkPath = watermarkFile.path;
    // String addWatermark =
    //     '-ignore_loop 0 -i "$watermarkPath" -filter_complex "overlay=x=(main_w-overlay_w):y=(main_h-overlay_h)" -c:a copy';
    final File fontPath = await _getFontPath();
    final String path = fontPath.path;
    final String waterMarkString =
        '''-vf "drawtext=text='This Is A teST':x=10:y=H-th-10:fontfile=$path:fontsize=35:fontcolor=white:box=1:boxcolor=black@0.5: boxborderw=30"''';

    final ProcessingResult _processingResult =
        await widget._trimmer.saveTrimmedVideo(
      startValue: _startValue,
      endValue: _endValue,
      ffmpegCommand: waterMarkString,
    );

    setState(() {
      _progressVisibility = false;
    });

    GallerySaver.saveVideo(_processingResult.outputPath);

    return _processingResult;
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
                  child: VideoViewer(
                      videoPlayerController:
                          widget._trimmer.videoPlayerController),
                ),
                Center(
                  child: TrimEditor(
                    viewerHeight: 50.0,
                    viewerWidth: MediaQuery.of(context).size.width,
                    maxDuration: Duration(seconds: 30),
                    minDuration: Duration(seconds: 5),
                    videoPlayerController:
                        widget._trimmer.videoPlayerController,
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
