import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/watermark_region.dart';

enum InpaintMethod {
  smart, // 스마트 배경 복원 (주변색 + 가장자리 페더링 보간)
  color, // 단색/주변 배경색 자동 추출 채우기
  blur,  // 부드러운 가우시안 블러
}

class ImageWatermarkService {
  /// 온디바이스 이미지 워터마크 삭제 실행
  static Future<File> removeWatermark({
    required File inputFile,
    required WatermarkRegion region,
    InpaintMethod method = InpaintMethod.smart,
  }) async {
    final bytes = await inputFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('이미지를 디코딩할 수 없습니다.');
    }

    final pixelRect = region.toPixelRect(image.width, image.height);
    final int rx = pixelRect.left.toInt().clamp(0, image.width - 1);
    final int ry = pixelRect.top.toInt().clamp(0, image.height - 1);
    final int rw = pixelRect.width.toInt().clamp(1, image.width - rx);
    final int rh = pixelRect.height.toInt().clamp(1, image.height - ry);

    if (method == InpaintMethod.blur) {
      _applyBlur(image, rx, ry, rw, rh);
    } else {
      _applySmartFill(image, rx, ry, rw, rh, isSmart: method == InpaintMethod.smart);
    }

    // 결과 저장 (임시 캐시 디렉터리)
    final tempDir = await getTemporaryDirectory();
    final outPath = '${tempDir.path}/clean_${DateTime.now().millisecondsSinceEpoch}.png';
    final outFile = File(outPath);
    await outFile.writeAsBytes(img.encodePng(image));

    return outFile;
  }

  /// 주변 배경색 샘플링 및 페더링 블렌딩 채우기
  static void _applySmartFill(
    img.Image image,
    int rx,
    int ry,
    int rw,
    int rh, {
    required bool isSmart,
  }) {
    // 1. 영역 테두리 주변(Ring) 4~8픽셀 샘플링하여 평균 배경색 계산
    const ring = 6;
    int sumR = 0, sumG = 0, sumB = 0, count = 0;

    for (int y = max(0, ry - ring); y <= min(image.height - 1, ry + rh + ring); y++) {
      for (int x = max(0, rx - ring); x <= min(image.width - 1, rx + rw + ring); x++) {
        // 워터마크 영역 내부는 샘플링에서 제외
        if (x >= rx && x < rx + rw && y >= ry && y < ry + rh) continue;

        final pixel = image.getPixel(x, y);
        sumR += pixel.r.toInt();
        sumG += pixel.g.toInt();
        sumB += pixel.b.toInt();
        count++;
      }
    }

    final avgR = count > 0 ? (sumR / count).round() : 255;
    final avgG = count > 0 ? (sumG / count).round() : 255;
    final avgB = count > 0 ? (sumB / count).round() : 255;

    // 2. 워터마크 영역 채우기 (경계선 페더링 가우시안 스무딩 적용)
    final featherDist = min(12, min(rw, rh) ~/ 4);

    for (int y = ry; y < ry + rh; y++) {
      for (int x = rx; x < rx + rw; x++) {
        // 테두리로부터의 최소 거리 계산
        final distLeft = x - rx;
        final distRight = (rx + rw - 1) - x;
        final distTop = y - ry;
        final distBottom = (ry + rh - 1) - y;
        final minDist = min(min(distLeft, distRight), min(distTop, distBottom));

        double blendFactor = 1.0;
        if (minDist < featherDist) {
          blendFactor = minDist / featherDist.toDouble();
          blendFactor = 0.5 - 0.5 * cos(blendFactor * pi); // Smooth Cosine S-curve
        }

        if (isSmart && minDist < featherDist * 2) {
          // 스마트 모드: 경계선과 가장 가까운 바깥쪽 픽셀 색상 참조
          final borderX = (distLeft < distRight) ? max(0, rx - 2) : min(image.width - 1, rx + rw + 1);
          final borderY = (distTop < distBottom) ? max(0, ry - 2) : min(image.height - 1, ry + rh + 1);
          final borderPixel = image.getPixel(borderX, borderY);

          final fillR = ((borderPixel.r * 0.5) + (avgR * 0.5)).round();
          final fillG = ((borderPixel.g * 0.5) + (avgG * 0.5)).round();
          final fillB = ((borderPixel.b * 0.5) + (avgB * 0.5)).round();

          final orig = image.getPixel(x, y);
          final r = (orig.r * (1 - blendFactor) + fillR * blendFactor).round();
          final g = (orig.g * (1 - blendFactor) + fillG * blendFactor).round();
          final b = (orig.b * (1 - blendFactor) + fillB * blendFactor).round();

          image.setPixelRgb(x, y, r, g, b);
        } else {
          final orig = image.getPixel(x, y);
          final r = (orig.r * (1 - blendFactor) + avgR * blendFactor).round();
          final g = (orig.g * (1 - blendFactor) + avgG * blendFactor).round();
          final b = (orig.b * (1 - blendFactor) + avgB * blendFactor).round();

          image.setPixelRgb(x, y, r, g, b);
        }
      }
    }
  }

  /// 고속 블러 처리
  static void _applyBlur(img.Image image, int rx, int ry, int rw, int rh) {
    const radius = 10;
    // 영역 내 픽셀 블러
    for (int y = ry; y < ry + rh; y++) {
      for (int x = rx; x < rx + rw; x++) {
        int r = 0, g = 0, b = 0, c = 0;
        for (int dy = -radius; dy <= radius; dy += 2) {
          final ny = (y + dy).clamp(0, image.height - 1);
          for (int dx = -radius; dx <= radius; dx += 2) {
            final nx = (x + dx).clamp(0, image.width - 1);
            final p = image.getPixel(nx, ny);
            r += p.r.toInt();
            g += p.g.toInt();
            b += p.b.toInt();
            c++;
          }
        }
        if (c > 0) {
          image.setPixelRgb(x, y, (r / c).round(), (g / c).round(), (b / c).round());
        }
      }
    }
  }
}

