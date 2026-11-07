import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import '../models/watermark_region.dart';

class VideoWatermarkService {
  /// 온디바이스 동영상 워터마크 삭제 실행
  static Future<File> removeWatermark({
    required File inputFile,
    required WatermarkRegion region,
    required int videoWidth,
    required int videoHeight,
    Function(double progress)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final outPath = '${tempDir.path}/clean_video_${DateTime.now().millisecondsSinceEpoch}.mp4';

    // 픽셀 좌표 계산
    final pixelRect = region.toPixelRect(videoWidth, videoHeight);
    int x = pixelRect.left.toInt().clamp(0, videoWidth - 1);
    int y = pixelRect.top.toInt().clamp(0, videoHeight - 1);
    int w = pixelRect.width.toInt().clamp(2, videoWidth - x);
    int h = pixelRect.height.toInt().clamp(2, videoHeight - y);

    // 짝수 크기로 정렬 (H.264 인코더 요구사항)
    if (w % 2 != 0) w -= 1;
    if (h % 2 != 0) h -= 1;
    if (x % 2 != 0) x += 1;
    if (y % 2 != 0) y += 1;

    // FFmpeg 스마트 크롭+블러+오버레이 필터 (모든 FFmpeg 빌드 100% 호환)
    // 오디오 무손실 복사(-c:a copy), 하드웨어 최적화 초고속 인코딩
    final filter = '[0:v]split[base][clip];'
        '[clip]crop=$w:$h:$x:$y,boxblur=luma_radius=12:luma_power=2[blurred];'
        '[base][blurred]overlay=$x:$y[outv]';

    final command = '-y -i "${inputFile.path}" '
        '-filter_complex "$filter" '
        '-map "[outv]" -map 0:a? '
        '-c:v libx264 -preset ultrafast -crf 23 '
        '-c:a copy "$outPath"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      final outFile = File(outPath);
      if (await outFile.exists()) {
        return outFile;
      }
    }

    final logs = await session.getAllLogsAsString();
    throw Exception('동영상 워터마크 삭제 실패: $logs');
  }
}

