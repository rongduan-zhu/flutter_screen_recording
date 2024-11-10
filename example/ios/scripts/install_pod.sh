#!/bin/bash

set -e

IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pushd "$IOS_DIR"

export PLATFORM_NAME=iphoneos
pod install
echo "installation done for >>>$PLATFORM_NAME<<<"

popd
