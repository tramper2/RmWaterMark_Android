import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/watermark_region.dart';
import '../services/image_watermark_service.dart';
import '../services/video_watermark_service.dart';
import 'result_screen.dart';

class EditorScreen extends StatefulWidget {
  final File mediaFile;
  final bool isVideo;

  const EditorScreen({
    super.key,
    required this.mediaFile,
    required this.isVideo,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  // 영역 비율 (0.0 ~ 1.0)
  WatermarkRegion? _region;
  InpaintMethod _inpaintMethod = InpaintMethod.smart;
  bool _isProcessing = false;

  // 비디오 컨트롤러
  VideoPlayerController? _videoController;
  int _mediaWidth = 1080;
  int _mediaHeight = 1920;
  bool _isInitialized = false;

  // 드래그 제스처 상태
  Offset? _dragStart;
  Offset? _dragCurrent;

  @override
  void initState() {
    super.initState();
    _initMedia();
  }

  Future<void> _initMedia() async {
    if (widget.isVideo) {
      _videoController = VideoPlayerController.file(widget.mediaFile);
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.play();

      _mediaWidth = _videoController!.value.size.width.toInt();
      _mediaHeight = _videoController!.value.size.height.toInt();
    } else {
      final decoded = await decodeImageFromList(await widget.mediaFile.readAsBytes());
      _mediaWidth = decoded.width;
      _mediaHeight = decoded.height;
    }

    // 기본 프리셋 (우하단 틱톡/쇼츠) 자동 셋업
    _applyPreset('br');

    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _applyPreset(String presetName) {
    final isPortrait = _mediaHeight > _mediaWidth;
    setState(() {
      _region = WatermarkRegion.preset(presetName, isPortrait: isPortrait);
    });
  }

  void _clearSelection() {
    setState(() {
      _region = null;
    });
  }

  Future<void> _executeRemoval() async {
    if (_region == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('워터마크 영역을 먼저 지정해 주세요! (하단의 빠른 지정 버튼 추천)'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      File cleanFile;

      if (widget.isVideo) {
        cleanFile = await VideoWatermarkService.removeWatermark(
          inputFile: widget.mediaFile,
          region: _region!,
          videoWidth: _mediaWidth,
          videoHeight: _mediaHeight,
        );
      } else {
        cleanFile = await ImageWatermarkService.removeWatermark(
          inputFile: widget.mediaFile,
          region: _region!,
          method: _inpaintMethod,
        );
      }

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              originalFile: widget.mediaFile,
              cleanedFile: cleanFile,
              isVideo: widget.isVideo,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('처리 중 오류 발생: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF121418),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1E26),
        title: Text(
          widget.isVideo ? '동영상 워터마크 지정' : '사진 워터마크 지정',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Colors.white70),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1A1E26),
                  title: const Text('💡 간편 사용 안내', style: TextStyle(color: Colors.white)),
                  content: const Text(
                    '1. 하단의 ⚡ 빠른 지정 버튼([우측 하단] 등)을 누르면 워터마크 영역이 1초 만에 잡힙니다.\n\n'
                    '2. 화면을 직접 손가락으로 드래그하여 네모 박스를 지정할 수도 있습니다.\n\n'
                    '3. [워터마크 지우기] 버튼을 누르면 스마트폰 안에서 바로 삭제됩니다!',
                    style: TextStyle(color: Color(0xFF9CA3AF), height: 1.4),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('확인', style: TextStyle(color: Color(0xFF6366F1))),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 메인 뷰포트 / 캔버스
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: AspectRatio(
                      aspectRatio: _mediaWidth / _mediaHeight,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            onPanStart: (details) {
                              setState(() {
                                _dragStart = details.localPosition;
                                _dragCurrent = details.localPosition;
                              });
                            },
                            onPanUpdate: (details) {
                              setState(() {
                                _dragCurrent = details.localPosition;
                              });
                            },
                            onPanEnd: (details) {
                              if (_dragStart != null && _dragCurrent != null) {
                                final left = details.localPosition.dx < _dragStart!.dx
                                    ? _dragCurrent!.dx
                                    : _dragStart!.dx;
                                final top = details.localPosition.dy < _dragStart!.dy
                                    ? _dragCurrent!.dy
                                    : _dragStart!.dy;
                                final w = (_dragCurrent!.dx - _dragStart!.dx).abs();
                                final h = (_dragCurrent!.dy - _dragStart!.dy).abs();

                                if (w > 15 && h > 15) {
                                  setState(() {
                                    _region = WatermarkRegion(
                                      leftRatio: (left / constraints.maxWidth).clamp(0.0, 1.0),
                                      topRatio: (top / constraints.maxHeight).clamp(0.0, 1.0),
                                      widthRatio: (w / constraints.maxWidth).clamp(0.01, 1.0),
                                      heightRatio: (h / constraints.maxHeight).clamp(0.01, 1.0),
                                    );
                                  });
                                }
                              }
                              setState(() {
                                _dragStart = null;
                                _dragCurrent = null;
                              });
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // 배경 미디어 (사진 또는 비디오)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: widget.isVideo && _videoController != null
                                      ? VideoPlayer(_videoController!)
                                      : Image.file(
                                          widget.mediaFile,
                                          fit: BoxFit.contain,
                                        ),
                                ),

                                // 워터마크 선택 영역 빨간색 반투명 박스 오버레이
                                if (_region != null)
                                  Positioned(
                                    left: _region!.leftRatio * constraints.maxWidth,
                                    top: _region!.topRatio * constraints.maxHeight,
                                    width: _region!.widthRatio * constraints.maxWidth,
                                    height: _region!.heightRatio * constraints.maxHeight,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF43F5E).withOpacity(0.4),
                                        border: Border.all(color: const Color(0xFFF43F5E), width: 2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          '워터마크',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            backgroundColor: Color(0x99000000),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                // 실시간 손가락 드래그 박스 오버레이
                                if (_dragStart != null && _dragCurrent != null)
                                  Positioned(
                                    left: _dragStart!.dx < _dragCurrent!.dx
                                        ? _dragStart!.dx
                                        : _dragCurrent!.dx,
                                    top: _dragStart!.dy < _dragCurrent!.dy
                                        ? _dragStart!.dy
                                        : _dragCurrent!.dy,
                                    width: (_dragCurrent!.dx - _dragStart!.dx).abs(),
                                    height: (_dragCurrent!.dy - _dragStart!.dy).abs(),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.3),
                                        border: Border.all(color: Colors.amber, width: 2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // 동영상 재생 컨트롤 (비디오 모드)
              if (widget.isVideo && _videoController != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _videoController!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                          color: const Color(0xFF6366F1),
                          size: 32,
                        ),
                        onPressed: () {
                          setState(() {
                            if (_videoController!.value.isPlaying) {
                              _videoController!.pause();
                            } else {
                              _videoController!.play();
                            }
                          });
                        },
                      ),
                      Expanded(
                        child: VideoProgressIndicator(
                          _videoController!,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Color(0xFF6366F1),
                            bufferedColor: Color(0xFF374151),
                            backgroundColor: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 하단 컨트롤 패널
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1E26),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. ⚡ 원터치 퀵 프리셋 칩
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text('⚡ 빠른 지정: ', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.bold)),
                          _PresetChip(label: '📍 우측 하단 (틱톡/쇼츠)', onTap: () => _applyPreset('br')),
                          _PresetChip(label: '📍 좌측 하단', onTap: () => _applyPreset('bl')),
                          _PresetChip(label: '📍 상단 자막', onTap: () => _applyPreset('top')),
                          _PresetChip(label: '📍 중앙 로고', onTap: () => _applyPreset('center')),
                          _PresetChip(label: '✕ 영역 초기화', isDanger: true, onTap: _clearSelection),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. 사진일 때 지우기 방식 선택
                    if (!widget.isVideo) ...[
                      Row(
                        children: [
                          const Text('지우기 방식: ', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF252A36),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<InpaintMethod>(
                                  value: _inpaintMethod,
                                  dropdownColor: const Color(0xFF252A36),
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  onChanged: (method) {
                                    if (method != null) {
                                      setState(() => _inpaintMethod = method);
                                    }
                                  },
                                  items: const [
                                    DropdownMenuItem(
                                      value: InpaintMethod.smart,
                                      child: Text('✨ 스마트 배경 복원 (자연 보간)'),
                                    ),
                                    DropdownMenuItem(
                                      value: InpaintMethod.color,
                                      child: Text('🎨 주변 배경색 자동 채우기'),
                                    ),
                                    DropdownMenuItem(
                                      value: InpaintMethod.blur,
                                      child: Text('💧 부드러운 가우시안 블러'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 3. 실행 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _executeRemoval,
                        icon: const Text('🪄', style: TextStyle(fontSize: 20)),
                        label: Text(
                          widget.isVideo ? '동영상 워터마크 지우기' : '워터마크 지우기',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF43F5E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 로딩 인디케이터 오버레이
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.75),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1E26),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFFF43F5E)),
                      const SizedBox(height: 20),
                      Text(
                        widget.isVideo ? '동영상 워터마크 삭제 중...' : '사진 워터마크 복원 중...',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '폰 안에서 직접 처리하고 있습니다\n잠시만 기다려주세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDanger;

  const _PresetChip({
    required this.label,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDanger ? const Color(0xFFEF4444).withOpacity(0.15) : const Color(0xFF252A36),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDanger ? const Color(0xFFEF4444).withOpacity(0.3) : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isDanger ? const Color(0xFFEF4444) : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
