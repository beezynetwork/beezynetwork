#!/bin/bash -x

# Environment prerequisites:
# 1) QT_PREFIX_PATH should be set to Qt libs folder
# 2) BOOST_ROOT should be set to the root of Boost
# 3) OPENSSL_ROOT_DIR should be set to the root of OpenSSL
#
# for example, place these lines to the end of your ~/.bashrc :
#
# export BOOST_ROOT=/home/user/boost_1_66_0
# export QT_PREFIX_PATH=/home/user/Qt5.10.1/5.10.1/gcc_64
# export OPENSSL_ROOT_DIR=/home/user/openssl
# export LINUX_DEPLOY_QT=/home/user/QtDeployment.appimage
# export LINUX_APPIMAGE_TOOL=/home/user/AppImageTool.appimage


ARCHIVE_NAME_PREFIX=beezy-linux-x64-

: "${BOOST_ROOT:?BOOST_ROOT should be set to the root of Boost, ex.: /home/user/boost_1_66_0}"
: "${QT_PREFIX_PATH:?QT_PREFIX_PATH should be set to Qt libs folder, ex.: /home/user/Qt5.10.1/5.10.1/gcc_64}"
: "${OPENSSL_ROOT_DIR:?OPENSSL_ROOT_DIR should be set to OpenSSL root folder, ex.: /home/user/openssl}"

if [ -n "$build_prefix" ]; then
  ARCHIVE_NAME_PREFIX=${ARCHIVE_NAME_PREFIX}${build_prefix}-
  build_prefix_label="$build_prefix "
fi

if [ "$testnet" == true ]; then
  testnet_def="-D TESTNET=TRUE"
  testnet_label="testnet "
  ARCHIVE_NAME_PREFIX=${ARCHIVE_NAME_PREFIX}testnet-
fi

if [ "$testnet" == true ] || [ -n "$qt_dev_tools" ]; then
  copy_qt_dev_tools=true
  copy_qt_dev_tools_label="devtools "
  ARCHIVE_NAME_PREFIX=${ARCHIVE_NAME_PREFIX}devtools-
fi


prj_root=$(pwd)

if [ "$1" == "skip_build" ]; then
        echo "Skipping build, only packing..."
	cd build/release;
else
echo "---------------- BUILDING PROJECT ----------------"
echo "--------------------------------------------------"

echo "Building...." 

rm -rf build; mkdir -p build/release; 
cd build/release; 
cmake $testnet_def -D STATIC=true -D ARCH=x86-64 -D BUILD_GUI=TRUE -D OPENSSL_ROOT_DIR="$OPENSSL_ROOT_DIR" -D CMAKE_PREFIX_PATH="$QT_PREFIX_PATH" -D CMAKE_BUILD_TYPE=Release ../..
if [ $? -ne 0 ]; then
    echo "Failed to run cmake"
    exit 1
fi

make -j2 daemon simplewallet connectivity_tool
if [ $? -ne 0 ]; then
    echo "Failed to make!"
    exit 1
fi

make -j1 beezy
if [ $? -ne 0 ]; then
    echo "Failed to make!"
    exit 1
fi

fi



read version_str <<< $(./src/beezyd --version | awk '/^beezy/ { print $2 }')
version_str=${version_str}

read commit_str <<< $(./src/beezyd  --version | grep -m 1 -P -o "(?<=\[)[0-9a-f]{7}")
commit_str=${commit_str}

echo $version_str
echo $commit_str


rm -rf beezy;
mkdir -p beezy/usr/bin;
mkdir -p beezy/usr/lib;
mkdir -p beezy/usr/share/applications;
mkdir -p beezy/usr/share/icons/hicolor/scalable/apps;
mkdir -p beezy/usr/share/icons/hicolor/256x256/apps;


rsync -a ../../src/gui/qt-daemon/layout/html ./beezy/usr/bin --exclude less --exclude package.json --exclude gulpfile.js

cp -Rv src/beezyd src/beezy src/simplewallet  src/connectivity_tool ./beezy/usr/bin
cp -Rv ../../utils/beezy.desktop ./beezy/usr/share/applications/beezy.desktop
cp -Rv ../../resources/app_icon.svg ./beezy/usr/share/icons/hicolor/scalable/apps/beezy.svg
cp -Rv ../../resources/app_icon_256.png ./beezy/usr/share/icons/hicolor/256x256/apps/beezy.png


echo "Exec=$prj_root/build/release/beezy/usr/bin/beezy" >> ./beezy/usr/share/applications/beezy.desktop
if [ $? -ne 0 ]; then
    echo "Failed to append deskyop file"
    exit 1
fi

$LINUX_DEPLOY_QT ./beezy/usr/share/applications/beezy.desktop -qmake=$QT_PREFIX_PATH/bin/qmake
if [ $? -ne 0 ]; then
    echo "Failed to run linuxqtdeployment"
    exit 1
fi

rm -f $prj_root/build/release/beezy/AppRun
cp -Rv ../../utils/beezy_appimage_wrapper.sh $prj_root/build/release/beezy/AppRun

package_filename=${ARCHIVE_NAME_PREFIX}${version_str}.AppImage

$LINUX_APPIMAGE_TOOL ./beezy ./$package_filename
if [ $? -ne 0 ]; then
    echo "Failed to run appimagetool"
    exit 1
fi




#pattern="*.AppImage"
#files=( $pattern )
#app_image_file=${files[0]}


#mv ./$app_image_file ./$package_filename

echo "Build success"

if [ -z "$upload_build" ]; then
    exit 0
fi

echo "Uploading..."

scp $package_filename beezy_build_server:/var/www/html/builds
if [ $? -ne 0 ]; then
    echo "Failed to upload to remote server"
    exit $?
fi

read checksum <<< $(sha256sum $package_filename | awk '/^/ { print $1 }' )

mail_msg="New ${build_prefix_label}${testnet_label}${copy_qt_dev_tools_label}build for linux-x64:<br>
<a href='https://build.beezy.org/builds/$package_filename'>https://build.beezy.org/builds/$package_filename</a><br>
sha256: $checksum"

echo "$mail_msg"

python3 ../../utils/build_mail.py "beezy linux-x64 ${build_prefix_label}${testnet_label}${copy_qt_dev_tools_label}build $version_str" "${emails}" "$mail_msg"

exit 0
