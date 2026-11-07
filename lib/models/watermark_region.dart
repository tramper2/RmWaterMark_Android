import 'package:flutter/material.dart';

/// 워터마크 선택 영역 모델 (0.0 ~ 1.0 정규화 비율 좌표)
class WatermarkRegion {
  final double leftRatio;
  final double topRatio;
  final double widthRatio;
  final double heightRatio;

  const WatermarkRegion({
    required this.leftRatio,
    required this.topRatio,
    required this.widthRatio,
    required this.heightRatio,
  });

  /// 정규화 Rect
  Rect toNormalizedRect() {
    return Rect.fromLTWH(leftRatio, topRatio, widthRatio, heightRatio);
  }

  /// 실제 픽셀 단위 Rect 변환
  Rect toPixelRect(int width, int height) {
    return Rect.fromLTWH(
      (leftRatio * width).clamp(0, width.toDouble()),
      (topRatio * height).clamp(0, height.toDouble()),
      (widthRatio * width).clamp(1, width.toDouble()),
      (heightRatio * height).clamp(1, height.toDouble()),
    );
  }

  /// 프리셋 생성자
  factory WatermarkRegion.preset(String presetName, {bool isPortrait = true}) {
    switch (presetName) {
      case 'br': // 우측 하단 (틱톡, 인스타 릴스, 유튜브 쇼츠, Gemini)
        final w = isPortrait ? 0.38 : 0.22;
        final h = isPortrait ? 0.12 : 0.15;
        return WatermarkRegion(
          leftRatio: 1.0 - w - 0.02,
          topRatio: 1.0 - h - 0.03,
          widthRatio: w,
          heightRatio: h,
        );
      case 'bl': // 좌측 하단
        final w = isPortrait ? 0.35 : 0.20;
        final h = isPortrait ? 0.10 : 0.12;
        return WatermarkRegion(
          leftRatio: 0.02,
          topRatio: 1.0 - h - 0.03,
          widthRatio: w,
          heightRatio: h,
        );
      case 'top': // 상단 자막/워터마크
        return const WatermarkRegion(
          leftRatio: 0.08,
          topRatio: 0.04,
          widthRatio: 0.84,
          heightRatio: 0.08,
        );
      case 'center': // 중앙 로고
        return const WatermarkRegion(
          leftRatio: 0.32,
          topRatio: 0.42,
          widthRatio: 0.36,
          heightRatio: 0.16,
        );
      default:
        return const WatermarkRegion(
          leftRatio: 0.7,
          topRatio: 0.85,
          widthRatio: 0.25,
          heightRatio: 0.1,
        );
    }
  }
}

