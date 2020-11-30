import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_trimmer/video_trimmer.dart';

class TrimEditor extends StatefulWidget {
  final double viewerWidth;

  final double viewerHeight;

  final Duration maxDuration;

  final Duration minDuration;

  final Color scrubberPaintColor;

  final int thumbnailQuality;

  final bool showDuration;

  final TextStyle durationTextStyle;

  final Function(double startValue) onChangeStart;

  final Function(double endValue) onChangeEnd;

  final Function(bool isPlaying) onChangePlaybackState;

  final Color primaryColor;

  final Color onSelectColor;

  final bool disabled;

  final VideoPlayerController videoPlayerController;

  TrimEditor({
    @required this.viewerWidth,
    @required this.viewerHeight,
    @required this.maxDuration,
    @required this.minDuration,
    @required this.videoPlayerController,
    this.disabled = false,
    this.scrubberPaintColor = Colors.white,
    this.thumbnailQuality = 75,
    this.showDuration = true,
    this.durationTextStyle = const TextStyle(color: Colors.white),
    this.onChangeStart,
    this.onChangeEnd,
    this.onChangePlaybackState,
    this.primaryColor = Colors.white,
    this.onSelectColor = Colors.yellow,
  })  : assert(viewerWidth != null),
        assert(viewerHeight != null),
        assert(scrubberPaintColor != null),
        assert(thumbnailQuality != null),
        assert(showDuration != null),
        assert(durationTextStyle != null);

  @override
  _TrimEditorState createState() => _TrimEditorState();
}

class _TrimEditorState extends State<TrimEditor> with TickerProviderStateMixin {
  File _videoFile;

  double _videoStartPos = 0.0;
  double _videoEndPos = 0.0;

  int _videoDuration = 0;
  int _currentPosition = 0;

  int _numberOfThumbnails = 0;

  double _minLengthPixels;

  double _start;
  double _end;
  double _sliderLength = 10.0;

  double _arrivedLeft;
  double _arrivedRight;

  ThumbnailViewer thumbnailWidget;

  Animation<double> _scrubberAnimation;
  AnimationController _animationController;
  Tween<double> _linearTween;

  ScrollController controller;

  double _maxRegion;

  double _fraction;
  double _offset = 0;

  Future<void> _initializeVideoController() async {
    if (_videoFile != null) {
      widget.videoPlayerController.addListener(() {
        final bool isPlaying = widget.videoPlayerController.value.isPlaying;

        if (isPlaying) {
          widget.onChangePlaybackState(true);
          setState(() {
            _currentPosition =
                widget.videoPlayerController.value.position.inMilliseconds;

            if (_currentPosition > _videoEndPos.toInt()) {
              widget.onChangePlaybackState(false);
              widget.videoPlayerController.pause();
              _animationController.stop();
            } else {
              if (!_animationController.isAnimating) {
                widget.onChangePlaybackState(true);
                _animationController.forward();
              }
            }
          });
        } else {
          if (widget.videoPlayerController.value.initialized) {
            if (_animationController != null) {
              if ((_scrubberAnimation.value).toInt() == (_end).toInt()) {
                _animationController.reset();
              }
              _animationController.stop();
              widget.onChangePlaybackState(false);
            }
          }
        }
      });

      widget.videoPlayerController.setVolume(1.0);

      _videoDuration =
          widget.videoPlayerController.value.duration.inMilliseconds;

      _videoStartPos = 0.0;
      widget.onChangeStart(_videoStartPos);

      _videoEndPos = widget.maxDuration.inMilliseconds.toDouble();
      if (widget.videoPlayerController.value.duration <= widget.maxDuration)
        _videoEndPos = widget
            .videoPlayerController.value.duration.inMilliseconds
            .toDouble();

      widget.onChangeEnd(_videoEndPos);

      _numberOfThumbnails =
          ((_videoDuration / widget.maxDuration.inMilliseconds) * 10).toInt();
      double _thumbnailWidth = _maxRegion / 10;

      if (_numberOfThumbnails <= 10) {
        _numberOfThumbnails = 10;
        _thumbnailWidth = _maxRegion / 10;
      }

      final ThumbnailViewer _thumbnailWidget = ThumbnailViewer(
        videoFile: _videoFile,
        videoDuration: _videoDuration,
        thumbnailHeight: widget.viewerHeight,
        thumbnailWidth: _thumbnailWidth,
        numberOfThumbnails: _numberOfThumbnails,
        quality: widget.thumbnailQuality,
        startSpace: _start,
        endSpace: widget.viewerWidth * 0.1,
        controller: controller,
      );
      thumbnailWidget = _thumbnailWidget;
    }
  }

  _scrollerListener() {
    controller.addListener(() async {
      setState(() {
        _offset = controller.offset;
        _videoStartPos =
            (_start - _arrivedLeft + controller.offset) * _fraction;
        _videoEndPos = (_end - _arrivedLeft + controller.offset) * _fraction;

        _linearTween.begin = _start + _sliderLength;
        _linearTween.end = _end;
        _animationController.duration =
            Duration(milliseconds: (_videoEndPos - _videoStartPos).toInt());
        _animationController.reset();

        widget.onChangeStart(_videoStartPos);
        widget.onChangeEnd(_videoEndPos);
      });

      await widget.videoPlayerController.pause();
      await widget.videoPlayerController
          .seekTo(Duration(milliseconds: _videoStartPos.toInt()));
    });
  }

  @override
  void initState() {
    super.initState();
    controller = ScrollController();
    _scrollerListener();

    _maxRegion = widget.viewerWidth * 0.8;
    _arrivedLeft = _start = widget.viewerWidth * 0.1;
    _arrivedRight = _end = widget.viewerWidth * 0.9;

    _videoFile = Trimmer.currentVideoFile;

    _initializeVideoController();

    if (_videoDuration > widget.maxDuration.inMilliseconds) {
      _fraction = widget.maxDuration.inMilliseconds / _maxRegion;
    } else {
      _fraction = _videoDuration / _maxRegion;
    }

    _minLengthPixels = (widget.minDuration.inMilliseconds /
            widget.maxDuration.inMilliseconds) *
        _maxRegion;
    if (Duration(milliseconds: _videoDuration).inSeconds <=
        widget.minDuration.inSeconds) _minLengthPixels = _maxRegion; //不能拖动

    // Defining the tween points
    _linearTween = Tween(begin: _start + _sliderLength, end: _end);

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_videoEndPos - _videoStartPos).toInt()),
    );

    _scrubberAnimation = _linearTween.animate(_animationController)
      ..addListener(() {
        setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _animationController.stop();
        }
      });
  }

  @override
  void dispose() async {
    widget.videoPlayerController.pause();
    widget.onChangePlaybackState(false);
    if (_videoFile != null) {
      widget.videoPlayerController.setVolume(0.0);
    }
    controller?.dispose();
    super.dispose();
  }

  Duration _formatTime(Duration duration) {
    String str = duration.toString();

    int p = int.parse(str.split('.')[1].substring(0, 1));

    int seconds = duration.inSeconds;

    if (p >= 5) seconds = seconds + 1;

    return Duration(seconds: seconds);
  }

  String _showTime(String type) {
    Duration _sd = _formatTime(Duration(milliseconds: _videoStartPos.toInt()));
    Duration _ed = _formatTime(Duration(milliseconds: _videoEndPos.toInt()));
    Duration _id = _ed - _sd;

    if (type == 'start') return _sd.toString().split('.')[0];
    if (type == 'end') return _ed.toString().split('.')[0];
    if (type == 'duration') return _id.toString().split('.')[0];

    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _videoPreview(),
        _videoFrameSlider(),
      ],
    );
  }

  bool _dragLeft = false;

  Widget _leftSlider() {
    Widget current = Container(
      height: 50,
      width: _sliderLength,
      color: _dragLeft ? widget.onSelectColor : widget.primaryColor,
    );

    current = GestureDetector(
      onHorizontalDragStart: widget.disabled
          ? null
          : (details) {
              _onLeftDragStart(details);
            },
      onHorizontalDragEnd: widget.disabled
          ? null
          : (details) {
              _onLeftDragEnd(details);
            },
      onHorizontalDragUpdate: widget.disabled
          ? null
          : (DragUpdateDetails details) async {
              await _onLeftDragUpdate(details);
            },
      child: current,
    );

    return Positioned(left: _start, child: current);
  }

  Widget _middleSliderSection() {
    Widget current = Container(
      height: 5,
      width: _sliderLength,
      color: widget.primaryColor.withOpacity(0.2),
    );

    current = GestureDetector(
      onHorizontalDragStart: widget.disabled
          ? null
          : (details) {
              _onLeftDragStart(details);
              _onRightDragStart(details);
            },
      onHorizontalDragEnd: widget.disabled
          ? null
          : (details) {
              _onLeftDragEnd(details);
              _onRightDragEnd(details);
            },
      onHorizontalDragUpdate: widget.disabled
          ? null
          : (DragUpdateDetails details) async {
              await _onLeftDragUpdate(details);
              await _onRightDragUpdate(details);
            },
      child: current,
    );

    return Positioned(
        left: _start + _sliderLength,
        right: widget.viewerWidth - _end,
        child: current);
  }

  bool _dragRight = false;
  Widget _rightSlider() {
    Widget current = Container(
      height: 50,
      width: _sliderLength,
      color: _dragRight ? widget.onSelectColor : widget.primaryColor,
    );

    current = GestureDetector(
      onHorizontalDragStart: widget.disabled
          ? null
          : (details) {
              _onRightDragStart(details);
            },
      onHorizontalDragEnd: widget.disabled
          ? null
          : (details) {
              _onRightDragEnd(details);
            },
      onHorizontalDragUpdate: widget.disabled
          ? null
          : (DragUpdateDetails details) async {
              await _onRightDragUpdate(details);
            },
      child: current,
    );

    return Positioned(left: _end, child: current);
  }

  void _onRightDragStart(DragStartDetails details) {
    setState(() {
      _dragRight = true;
    });
  }

  void _onRightDragEnd(DragEndDetails details) {
    setState(() {
      _dragRight = false;
    });
  }

  Future<void> _onRightDragUpdate(DragUpdateDetails details) async {
    if (_end + details.delta.dx > _arrivedRight) {
      setState(() {
        _end = _arrivedRight;
        _videoEndPos = _fraction * (_end + _offset + -_arrivedLeft);
      });

      return;
    }

    if (_end - _start + details.delta.dx < _minLengthPixels) return;

    setState(() {
      _end = _end + details.delta.dx;
      _videoEndPos = _fraction * (_end + _offset - _arrivedLeft);

      widget.onChangeEnd(_videoEndPos);
    });

    await widget.videoPlayerController.pause();
    await widget.videoPlayerController
        .seekTo(Duration(milliseconds: _videoStartPos.toInt()));

    _linearTween.end = _end;
    _animationController.duration =
        Duration(milliseconds: (_videoEndPos - _videoStartPos).toInt());
    _animationController.reset();
  }

  Future<void> _onLeftDragUpdate(DragUpdateDetails details) async {
    if (_start + details.delta.dx < _arrivedLeft) {
      setState(() {
        _start = _arrivedLeft;
      });

      return;
    }

    if (_end - _start - details.delta.dx < _minLengthPixels) return;

    setState(() {
      _start = _start + details.delta.dx;
      _videoStartPos = _fraction * (_start + _offset - _arrivedLeft);
      widget.onChangeStart(_videoStartPos);
    });

    await widget.videoPlayerController.pause();
    await widget.videoPlayerController
        .seekTo(Duration(milliseconds: _videoStartPos.toInt()));

    _linearTween.begin = _start + _sliderLength;
    _animationController.duration =
        Duration(milliseconds: (_videoEndPos - _videoStartPos).toInt());
    _animationController.reset();
  }

  void _onLeftDragEnd(DragEndDetails details) {
    setState(() {
      _dragLeft = false;
    });
  }

  void _onLeftDragStart(DragStartDetails details) {
    setState(() {
      _dragLeft = true;
    });
  }

  Widget _videoPreview() {
    return widget.showDuration
        ? Container(
            width: widget.viewerWidth,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  Text(
                    _showTime('start'),
                    style: widget.durationTextStyle,
                  ),
                  Text(
                    _showTime('duration'),
                    style: widget.durationTextStyle,
                  ),
                  Text(
                    _showTime('end'),
                    style: widget.durationTextStyle,
                  ),
                ],
              ),
            ),
          )
        : Container();
  }

  Widget _videoFrameSlider() {
    return Stack(
      children: [
        Container(
          height: widget.viewerHeight,
          width: widget.viewerWidth,
          child: thumbnailWidget == null ? Column() : thumbnailWidget,
        ),
        _leftSlider(),
        _rightSlider(),
        _middleSliderSection(),
        // Positioned(
        //   left: _start + _sliderLength,
        //   right: widget.viewerWidth - _end,
        //   bottom: 0,
        //   child: Container(height: 1, color: Colors.white),
        // ),
        // Positioned(
        //   left: _scrubberAnimation.value,
        //   top: 0,
        //   bottom: 0,
        //   child: Container(
        //     width: 2,
        //     color: _scrubberAnimation.value <= (_start + _sliderLength + 1)
        //         ? Colors.transparent
        //         : videoPlayerController.value.isPlaying
        //             ? widget.onSelectColor
        //             : widget.onSelectColor,
        //   ),
        // ),
      ],
    );
  }
}
