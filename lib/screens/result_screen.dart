import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

class ResultScreen extends StatefulWidget {
  final File originalFile;
  final File cleanedFile;
  final bool isVideo;

  const ResultScreen({
    super.key,
    required this.originalFile,
    required this.cleanedFile,
    required this.isVideo,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _showOriginal = false;
  bool _isSaving = false;
  bool _isSaved = false;

  VideoPlayerController? _cleanedVideoController;
  VideoPlayerController? _origVideoController;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _cleanedVideoController = VideoPlayerController.file(widget.cleanedFile)
        ..initialize().then((_) {
          _cleanedVideoController!.setLooping(true);
          _cleanedVideoController!.play();
          setState(() {});
        });

      _origVideoController = VideoPlayerController.file(widget.originalFile)
        ..initialize().then((_) {
          _origVideoController!.setLooping(true);
          setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _cleanedVideoController?.dispose();
    _origVideoController?.dispose();
    super.dispose();
  }

  Future<void> _saveToGallery() async {
    setState(() => _isSaving = true);
    try {
      if (widget.isVideo) {
        await Gal.putVideo(widget.cleanedFile.path);
      } else {
        await Gal.putImage(widget.cleanedFile.path);
      }

      setState(() {
        _isSaving = false;
        _isSaved = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 스마트폰 갤러리에 저장되었습니다!'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('갤러리 저장 실패: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _shareFile() async {
    final xFile = XFile(widget.cleanedFile.path);
    await Share.shareXFiles([xFile], text: '워터마크를 제거한 파일입니다.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1E26),
        title: const Text(
          '🎉 워터마크 삭제 완료',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 미리보기 영역 (터치 앤 홀드 비포/애프터 비교)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTapDown: (_) {
                      setState(() => _showOriginal = true);
                      if (widget.isVideo) {
                        _cleanedVideoController?.pause();
                        _origVideoController?.play();
                      }
                    },
                    onTapUp: (_) {
                      setState(() => _showOriginal = false);
                      if (widget.isVideo) {
                        _origVideoController?.pause();
                        _cleanedVideoController?.play();
                      }
                    },
                    onTapCancel: () {
                      setState(() => _showOriginal = false);
                      if (widget.isVideo) {
                        _origVideoController?.pause();
                        _cleanedVideoController?.play();
                      }
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: widget.isVideo
                              ? (_showOriginal
                                  ? (_origVideoController != null && _origVideoController!.value.isInitialized
                                      ? AspectRatio(
                                          aspectRatio: _origVideoController!.value.aspectRatio,
                                          child: VideoPlayer(_origVideoController!),
                                        )
                                      : const SizedBox())
                                  : (_cleanedVideoController != null && _cleanedVideoController!.value.isInitialized
                                      ? AspectRatio(
                                          aspectRatio: _cleanedVideoController!.value.aspectRatio,
                                          child: VideoPlayer(_cleanedVideoController!),
                                        )
                                      : const SizedBox()))
                              : Image.file(
                                  _showOriginal ? widget.originalFile : widget.cleanedFile,
                                  fit: BoxFit.contain,
                                ),
                        ),

                        // 상단 비포/애프터 뱃지
                        Positioned(
                          top: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: _showOriginal
                                  ? const Color(0xFFEF4444).withValues(alpha: 0.85)
                                  : const Color(0xFF10B981).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _showOriginal ? '🔴 원본 (손을 떼면 제거본)' : '✨ 워터마크 제거본',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),

                        // 하단 팁
                        Positioned(
                          bottom: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              '👇 화면을 꾹 누르고 있으면 원본과 비교할 수 있어요',
                              style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 액션 버튼 패널
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1E26),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. 갤러리 저장 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveToGallery,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Icon(_isSaved ? Icons.check_circle_rounded : Icons.save_alt_rounded),
                      label: Text(
                        _isSaved ? '갤러리에 저장 완료!' : '스마트폰 갤러리에 저장',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSaved ? const Color(0xFF059669) : const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 2. 공유 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _shareFile,
                      icon: const Icon(Icons.share_rounded, size: 20),
                      label: const Text('카카오톡 / 다른 앱으로 공유', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.15)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 3. 홈으로 돌아가기
                  TextButton(
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    child: const Text('새 파일 작업하기', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
