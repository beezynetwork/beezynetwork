set -x #echo on
curr_path=${BASH_SOURCE%/*}

# check that all the required environment vars are set
: "${beezy_QT_PATH:?variable not set, see also macosx_build_config.command}"
: "${beezy_BOOST_ROOT:?variable not set, see also macosx_build_config.command}"
: "${beezy_BOOST_LIBS_PATH:?variable not set, see also macosx_build_config.command}"
: "${beezy_BUILD_DIR:?variable not set, see also macosx_build_config.command}"
: "${CMAKE_OSX_SYSROOT:?CMAKE_OSX_SYSROOT should be set to macOS SDK path, e.g.: /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.13.sdk}"

BUILD_DIR=$curr_path/../$beezy_BUILD_DIR/macos_xcodeproj
BUILD_TYPE=Release

rm -rf $BUILD_DIR
mkdir -p "$BUILD_DIR/$BUILD_TYPE"
cd "$BUILD_DIR/$BUILD_TYPE"

cmake -D BUILD_GUI=TRUE -D CMAKE_PREFIX_PATH="$beezy_QT_PATH/clang_64" -D CMAKE_BUILD_TYPE=$BUILD_TYPE -D BOOST_ROOT="$beezy_BOOST_ROOT" -D BOOST_LIBRARYDIR="$beezy_BOOST_LIBS_PATH" -G Xcode ../../..

