#!/bin/sh

set -e

if [ -z "$DART_SDK_SRC_PATH" ]; then
  echo "Expected DART_SDK_SRC_PATH to be set pointing to SDK checkout"
  exit 1
fi

dart tool/generate.dart $1

dart run build_runner build --delete-conflicting-outputs

generated_bytes=$(du -s lib/graphql/__generated__ | awk '{print $1}')
generated_files=$(ls -l lib/graphql/__generated__/*.dart | wc -l)

echo "Generated $generated_bytes bytes across $generated_files files"

DART_CONFIGURATION=${DART_CONFIGURATION:-ReleaseX64}
DART_CONFIGURATION_DIR=$DART_SDK_SRC_PATH/out/$DART_CONFIGURATION

ninja -C $DART_CONFIGURATION_DIR gen_kernel.exe vm_platform_strong.dill

echo "Running gen_kernel.exe (AOT)"
time $DART_CONFIGURATION_DIR/gen_kernel.exe                                    \
  --platform $DART_CONFIGURATION_DIR/vm_platform_strong.dill                   \
  --aot --tfa                                                                  \
  --packages $PWD/.dart_tool/package_config.json                               \
  -o /tmp/output.dill                                                          \
  package:flutter_ferry_aot_stress_test/main.dart