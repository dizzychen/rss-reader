#!/bin/bash
export DEVECO_HOME="/Applications/DevEco-Studio.app/Contents"
export NODE_HOME="$DEVECO_HOME/tools/node"
export OHPM_HOME="$DEVECO_HOME/tools/ohpm"
export HVIGOR_HOME="$DEVECO_HOME/tools/hvigor"
export DEVECO_SDK_HOME="$DEVECO_HOME/sdk"
export PATH="$NODE_HOME/bin:$OHPM_HOME/bin:$HVIGOR_HOME/bin:$PATH"

cd /Users/dizzychen/DevEcoStudioProjects/RssReader

BUILD_MODE="${1:-debug}"

echo "=== Installing dependencies ==="
ohpm install

if [ "$BUILD_MODE" = "release" ]; then
  echo "=== Building Release APP (for AppGallery Connect) ==="
  hvigorw clean --no-daemon 2>&1
  hvigorw assembleApp -p product=default -p buildMode=release --no-daemon 2>&1
else
  echo "=== Building Debug HAP ==="
  hvigorw assembleHap --no-daemon 2>&1
fi

echo "=== exit: $? ==="

if [ "$BUILD_MODE" = "release" ]; then
  echo ""
  echo "Release 包输出路径: entry/build/default/outputs/default/"
  echo "请将 .app 文件上传到 AppGallery Connect"
fi
