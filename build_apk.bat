@echo off
chcp 65001 >nul
title 워터마크 지우개 APK 빌더

echo ========================================================
echo    📱 워터마크 지우개 안드로이드 APK 빌드 시작
echo ========================================================
echo.

set "JAVA_HOME=C:\Program Files\Unity\Hub\Editor\6000.3.9f1\Editor\Data\PlaybackEngines\AndroidPlayer\OpenJDK"
set "ANDROID_HOME=d:\Projects\Android\RmWaterMark\android_sdk"
set "ANDROID_SDK_ROOT=%ANDROID_HOME%"
set "PATH=%JAVA_HOME%\bin;%ANDROID_HOME%\platform-tools;D:\download\flutter\bin;%PATH%"

cd /d "%~dp0"

echo [1/2] 의존성 패키지 확인 중...
call "D:\download\flutter\bin\flutter.bat" pub get

echo.
echo [2/2] 안드로이드 APK 빌드 중... (잠시만 기다려주세요)
call "D:\download\flutter\bin\flutter.bat" build apk --debug

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================================
    echo    🎉 APK 빌드 성공!
    echo    생성 위치: build\app\outputs\flutter-apk\app-debug.apk
    echo ========================================================
    echo.
    echo 스마트폰을 USB로 연결하고 위 APK 파일을 스마트폰에 넣거나 카톡/클라우드로 전송하여 설치하세요!
) else (
    echo.
    echo ❌ APK 빌드 중 오류가 발생했습니다.
)

pause
