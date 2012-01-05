#!/bin/bash

# MacOSX10.4.universal.sdk may allow PPC targetting toolchains.
DARWIN_VER=$1

if [ "$DARWIN_VER" = "8" ] ; then
 OSX_SDK_VER=MacOSX10.4u
 OSX_SDK_PKG=MacOSX10.4.Universal.pkg
elif [ "$DARWIN_VER" = "9" ] ; then
 OSX_SDK_VER=MacOSX10.5
elif [ "$DARWIN_VER" = "10" ] ; then
 OSX_SDK_VER=MacOSX10.6
else
 echo "Please specify Darwin version (8, 9 or 10) as the first parameter."
 exit 1
fi

UNAME=$(uname -s)
case "$UNAME" in
 "MINGW"*)
  UNAME=Windows
 ;;
esac

PKGSUFFIX=-${DARWIN_VER}-${UNAME}

rm -rf cctools-809-build-${DARWIN_VER}
rm -rf xchain-ma-build-${DARWIN_VER}
rm -rf odcctools-9.2-ld-build-${DARWIN_VER}

$(dirname $0)/build_macosx_xtc.sh ${DARWIN_VER} apple      keep-going save-temps > cctools-809-build-${DARWIN_VER}.log      2>&1
$(dirname $0)/build_macosx_xtc.sh ${DARWIN_VER} iphonedev  keep-going save-temps > odcctools-9.2-ld-build-${DARWIN_VER}.log 2>&1
$(dirname $0)/build_macosx_xtc.sh ${DARWIN_VER} xchain     keep-going save-temps > xchain-ma-build-${DARWIN_VER}.log        2>&1

rm odcctools-9.2-ld-build${PKGSUFFIX}.7z
find odcctools-9.2-ld-build-${DARWIN_VER} -name ".svn" -exec rm -rf {} \;
7za a odcctools-9.2-ld-build${PKGSUFFIX}.7z odcctools-9.2-ld-build-${DARWIN_VER} odcctools-9.2-ld-build-${DARWIN_VER}.log

rm cctools-809-build${PKGSUFFIX}.7z
7za a cctools-809-build${PKGSUFFIX}.7z cctools-809-build-${DARWIN_VER} cctools-809-build-${DARWIN_VER}.log

rm xchain-ma-build${PKGSUFFIX}.7z
rm -rf xchain-ma-build-${DARWIN_VER}/.git
7za a xchain-ma-build${PKGSUFFIX}.7z xchain-ma-build-${DARWIN_VER} xchain-ma-build-${DARWIN_VER}.log

echo "All done: cctools-809-build${PKGSUFFIX}.7z xchain-ma-build${PKGSUFFIX}.7z"
 
