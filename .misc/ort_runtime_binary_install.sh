#!/bin/bash
# scripts/setup_ort.sh — run ONCE after cloning the project

VERSION="1.20.1"

echo "Setting up ORT for Android..."
curl -L "https://github.com/microsoft/onnxruntime/releases/download/v${VERSION}/onnxruntime-android-${VERSION}.aar" \
  -o /tmp/ort-android.aar

mkdir -p android/app/src/main/jniLibs/{arm64-v8a,x86_64,armeabi-v7a}
unzip -o /tmp/ort-android.aar \
  "jni/arm64-v8a/libonnxruntime.so" \
  "jni/x86_64/libonnxruntime.so" \
  "jni/armeabi-v7a/libonnxruntime.so" \
  -d /tmp/ort-android-extracted/

cp /tmp/ort-android-extracted/jni/arm64-v8a/libonnxruntime.so \
   android/app/src/main/jniLibs/arm64-v8a/
cp /tmp/ort-android-extracted/jni/x86_64/libonnxruntime.so \
   android/app/src/main/jniLibs/x86_64/
cp /tmp/ort-android-extracted/jni/armeabi-v7a/libonnxruntime.so \
   android/app/src/main/jniLibs/armeabi-v7a/

echo "Setting up ORT for iOS..."
curl -L "https://github.com/microsoft/onnxruntime/releases/download/v${VERSION}/onnxruntime-ios-xcframework-${VERSION}.zip" \
  -o /tmp/ort-ios.zip

mkdir -p ios/Frameworks
unzip -o /tmp/ort-ios.zip -d ios/Frameworks/

echo "Done! Don't forget to add onnxruntime.xcframework to Xcode (Embed & Sign)"