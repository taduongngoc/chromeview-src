#!/bin/bash
# Builds the Chromium bits needed by ChromeView.

set -o errexit  # Stop the script on the first error.
set -o nounset  # Catch un-initialized variables.

# Prepare the output area.
mkdir -p ~/crbuild.www/archives
mkdir -p ~/crbuild.www/staging
mkdir -p ~/crbuild.www/logs

# Build Chromium.
# https://code.google.com/p/chromium/wiki/UsingGit
if [ ! -z GCLIENT_SYNC ] ; then
  cd ~/chromium/
  # Syncing twice because of crbugs.com/237234
  gclient sync --jobs 16 --reset --delete_unversioned_trees
  gclient sync --jobs 16 --reset --delete_unversioned_trees
fi

cd ~/chromium/src
echo "Building $(git rev-parse HEAD)"

CPUS=$(grep -c 'processor' /proc/cpuinfo)

if [ -f ~/.build_arm ] ; then
  set +o nounset  # Chromium scripts are messy.
  # NOTE: "source" is bash-only, "." is POSIX. 
  . build/android/envsetup.sh --target-arch=arm
  set -o nounset  # Catch un-initialized variables.
  android_gyp
  ninja -C out/Release -k0 -j$CPUS libwebviewchromium android_webview_apk \
      content_shell_apk chromium_testshell
fi

if [ -f ~/.build_x86 ] ; then
  set +o nounset  # Chromium scripts are messy.
  . build/android/envsetup.sh --target-arch=x86
  set -o nounset  # Catch un-initialized variables.
  android_gyp
  ninja -C out/Release -k0 -j$CPUS libwebviewchromium android_webview_apk \
      content_shell_apk chromium_testshell
fi


# Package the build.
cd ~/chromium/src
REV=$(git rev-parse HEAD)
STAGING=~/crbuild.www/staging/$REV
rm -rf $STAGING
mkdir -p $STAGING

# Structure.
mkdir -p $STAGING/assets
mkdir -p $STAGING/libs
mkdir -p $STAGING/res
mkdir -p $STAGING/src


# ContentShell core -- use this if android_webview doesn't work out.
#scp out/Release/content_shell/assets/* assets/
#scp -r out/Release/content_shell_apk/libs/* libs/
#scp -r content/shell/android/java/res/* ~/crbuilds/$REV/res/
#scp -r content/shell/android/java/src/* ~/crbuilds/$REV/src/
#scp -r content/shell_apk/android/java/res/* ~/crbuilds/$REV/res/

# android_webview
cp out/Release/android_webview_apk/assets/*.pak $STAGING/assets/
cp -r out/Release/android_webview_apk/libs/* $STAGING/libs/
rm $STAGING/libs/**/gdbserver
cp -r android_webview/java/src/* $STAGING/src/

## Dependencies inferred from android_webview/Android.mk

# Resources.
cp -r content/public/android/java/resource_map/* $STAGING/src/
cp -r ui/android/java/resource_map/* $STAGING/src/
cp -r chrome/android/java/res/* $STAGING/res/

# ContentView dependencies.
cp -r base/android/java/src/* $STAGING/src/
cp -r content/public/android/java/src/* $STAGING/src/
cp -r media/base/android/java/src/* $STAGING/src/
cp -r net/android/java/src/* $STAGING/src/
cp -r ui/android/java/src/* $STAGING/src/
cp -r third_party/eyesfree/src/android/java/src/* $STAGING/src/

# Strip a ContentView file that's not supposed to be here.
rm $STAGING/src/org/chromium/content/common/common.aidl

# Get rid of the version control directory in eyesfree.
rm -rf $STAGING/src/com/googlecode/eyesfree/braille/.svn
rm -rf $STAGING/src/com/googlecode/eyesfree/braille/.git

# Browser components.
cp -r components/web_contents_delegate_android/android/java/src/* $STAGING/src/
cp -r components/navigation_interception/android/java/src/* $STAGING/src/

# Generated files.
cp -r out/Release/gen/templates/* $STAGING/src/

# JARs.
cp -r out/Release/lib.java/guava_javalib.jar $STAGING/libs/
cp -r out/Release/lib.java/jsr_305_javalib.jar $STAGING/libs/

# android_webview generated sources. Must come after all the other sources.
cp -r android_webview/java/generated_src/* $STAGING/src/

# Archive.
ARCHIVE="archives/$REV"
if [ -f ~/.build_arm ] ; then
  ARCHIVE="$ARCHIVE-arm"
fi
if [ -f ~/.build_x86 ] ; then
  ARCHIVE="$ARCHIVE-x86"
fi
cd $STAGING
tar -czvf "$HOME/crbuild.www/$ARCHIVE.tar.gz" .

# Clean up the build directory.
cd ~/crbuilds
rm -rf $STAGING

# Update the latest-build info.
echo -n $REV > ~/crbuild.www/LATEST_REV
echo -n $ARCHIVE.tar.gz > ~/crbuild.www/LATEST
