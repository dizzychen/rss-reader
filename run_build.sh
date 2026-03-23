#!/bin/bash
export DEVECO_HOME="/Applications/DevEco-Studio.app/Contents"
export NODE_HOME="$DEVECO_HOME/tools/node"
export OHPM_HOME="$DEVECO_HOME/tools/ohpm"
export HVIGOR_HOME="$DEVECO_HOME/tools/hvigor"
export DEVECO_SDK_HOME="$DEVECO_HOME/sdk"
export PATH="$NODE_HOME/bin:$OHPM_HOME/bin:$HVIGOR_HOME/bin:$PATH"

cd /Users/dizzychen/DevEcoStudioProjects/rss-reader

echo "=== Installing dependencies ==="
ohpm install
echo "=== Building ==="
hvigorw assembleHap --no-daemon 2>&1
echo "=== exit: $? ==="
