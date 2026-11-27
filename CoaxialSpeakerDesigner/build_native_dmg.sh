#!/bin/bash
# Build script for Pure Native SwiftUI macOS Application & CoaxialSpeakerDesigner_Native.dmg
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "${SCRIPT_DIR}"

python3 package_native_dmg.py
