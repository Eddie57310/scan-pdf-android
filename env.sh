#!/usr/bin/env bash
# 加载本项目的开发环境：source ./env.sh
export JAVA_HOME="$HOME/jdk17"
export ANDROID_HOME="$HOME/Android"
export ANDROID_SDK_ROOT="$HOME/Android"
export PATH="$HOME/flutter/bin:$HOME/jdk17/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
echo "环境已加载: flutter + jdk17 + android sdk"
