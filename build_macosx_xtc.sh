#!/bin/bash

# Current problems:
# None of the MacOSX10.*.pkg files in xcode_3.2.6_and_ios_sdk_4.3.dmg contain anything other than usr/lib/i686-apple-darwin10 (i.e. there's no 8 or 9 in any of them), so
# this prevents the final compilers from working as they look for darwin9. One fix would be to make a symlink i686-apple-darwin9 to i686-apple-darwin10

# Ideally, I would build it for target of i686-apple-darwin10, however, gcc gets configured  differently when this is done and our as is incompatiable with this gcc:
# 1:37:Rest of line ignored. 1st junk character valued 34 (").
# 1:38:Unknown pseudo-op: .loc
#        .file 1 "../../gcc-5666.3/gcc/libgcc2.c"
#        .loc 1 567 0
# The best fix for all of this is to take Apple's latest as sources and merge it with the odcc tools.

# final-install-all/home/nonesuch/src/cross-mac/i686-apple-darwin9/usr/bin/i686-apple-darwin9-g++ -isysroot ~/src/cross-mac/final-install-all/home/nonesuch/src/cross-mac/i686-apple-darwin9/Developer/SDKs/MacOSX10.5.sdk -mmacosx-version-min=10.5 -DMAXOSX_DEPLOYEMENT_TARGET=10.5 ndk-stack.c -o ndk-stack.c.o
# ld: library not found for -lstdc++
# collect2: ld returned 1 exit status

# use meld ~/src/cross-mac/final-install/home/nonesuch/src/cross-mac/i686-apple-darwin9 ~/src/cross-mac/i686-apple-darwin9
# to see these important differences:

# libstdc++ is completely ignored by all of this (c++ compilers are built though)...
# so the final package ends up without c++ headers. Paths missing are:
# i686-apple-darwin9/usr/include/c++/4.0.0
# i686-apple-darwin9/usr/include/c++/4.2.1 [ symlink to -> 4.0.0 ]
# i686-apple-darwin9/usr/lib/libstdc++.6.0.4.dylib
# i686-apple-darwin9/usr/lib/libstdc++.6.dylib

# Should probably make everything into a prefix of /, but that's nasty. Best to fix any hard coded paths.

# I would not recommend using gcc > 4.5 with Ubuntu 11 (natty) as I've run into problems with 4.6
# Before running this, you need to:
# sudo apt-get install gobjc gobjc++ gobjc-multilib gobjc++-multilib gobjc++-multilib uuid-dev
# ..and also, the appropriate (i.e. gcc version specific) equivalent of:
# sudo apt-get install gobjc-4.5 gobjc-4.5-multilib

# Lots of references:
# [1] http://devs.openttd.org/~truebrain/compile-farm/apple-darwin9.txt
# [2] http://code.google.com/p/iphonedevonlinux/source/browse/trunk/toolchain.sh
# [3] https://github.com/tatsh/xchain
# [4] http://code.google.com/p/toolwhip/
# [5] http://www.theiphonewiki.com/wiki/index.php?title=Toolchain_2.0
# [6] http://easleyk.wordpress.com/2010/02/10/cross-compiling-firefox-for-mac-on-linux/
# [7] http://code.google.com/p/iphone-dev/wiki/Building
# [8] http://aakash-bapna.blogspot.com/2007/10/iphone-non-official-sdk-aka-toolchain.html

# Valid values for USE_CCTOOLS are iphonedev, xchain or apple.
# xchain is based on (and then fixed) iphonedev so seems to be the only choice.
USE_CCTOOLS="xchain"
XCHAIN_VER=-ma

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

OSX_SDK=${OSX_SDK_VER}.sdk

if [ -z $OSX_SDK_PKG ] ; then
 OSX_SDK_PKG=${OSX_SDK_VER}.pkg
fi

# Doesn't report missing gobjc stuff as detection of that is more complicated.
NEEDED_TOOLS="dmg2img xar xml2 zcat cpio svn patch bison flex"

export TARGET=i686-apple-darwin${DARWIN_VER}

missing_tools()
{
 local _MISSING_TOOLS=""
 while [ ! "$1" = "" ] ; do
  TOOL=$1
  if [ -z `which $TOOL` ] ; then
   _MISSING_TOOLS="$_MISSING_TOOLS $TOOL"
  fi
  shift
 done
 echo $_MISSING_TOOLS
}

unpack_pkg()
{
 xar -xf $1 Payload
 if [ ! "$?" = "0" ] ; then
  echo "Failed to find pkg $1"
  exit 1
 fi

 cat Payload | zcat | cpio -id
 rm -f Payload
}

# from toolchain.sh
# sudo mount -t hfsplus -o loop,offset=36864 xcode.img xcode-3.2.6
# ..doesn't work:
# hfs: invalid secondary volume header
# hfs: unable to find HFS+ superblock
# from http://code.google.com/p/iphonedevonlinux/issues/detail?id=27#c1
# ..works:
# losetup -o 36864 /dev/loop0 xcode.img
# mount -t hfsplus /dev/loop0 xcode-3.2.6
mount_img()
{
 local _IMG=$1
 local _DIR=$2
 local _RESULT=

 [ -d $_DIR ] || mkdir $_DIR

 sudo modprobe hfsplus

 while true; do
  sudo losetup -o 36864 /dev/loop0 $_IMG
  _RESULT=$?
  [ $_RESULT = 0 ] && break
  # Workaround for if this script is interrupted between mount and umount
  [ $_RESULT = 2 ] && sudo losetup -d /dev/loop0 2>&1 1>/dev/null
 done

 while true; do
  sudo mount -t hfsplus /dev/loop0 $_DIR
  _RESULT=$?
  [ $_RESULT = 0 ] && break
 done
}

umount_img()
{
 local _IMG=$1
 local _DIR=$2
 local _RESULT=

 while true; do
  sudo umount $_DIR 2>&1 1>/dev/null
  _RESULT=$?
  [ $_RESULT = 0 ] && break
 done

 while true; do
  sudo losetup -d /dev/loop0 2>&1 1>/dev/null
  _RESULT=$?
  [ $_RESULT = 0 ] && break
 done
}

ROOT=$PWD
PREFIX=/$TARGET
# Not sure if DARWIN_PREFIX is required.
export DARWIN_PREFIX=$PREFIX
[ -d $PREFIX ]   || sudo mkdir $PREFIX
USER=`whoami`
sudo chown $USER:$USER $PREFIX
[ -d $ROOT/bin ] && PATH=$ROOT/bin:$PATH
MISSING_TOOLS=$(missing_tools $NEEDED_TOOLS)

if [ "$MISSING_TOOLS" = "xar" ] ; then
 echo "xar missing, Ubuntu Natty (and other creatures) doesn't provide a package, so compiling from source"
 [ -f xar-1.5.2.tar.gz ] || wget -c http://xar.googlecode.com/files/xar-1.5.2.tar.gz
 tar -xzvf xar-1.5.2.tar.gz
 pushd xar-1.5.2
  ./configure --prefix=$PWD/..
  make
  make install
 popd
 MISSING_TOOLS=$(missing_tools $NEEDED_TOOLS)
fi

if [ ! "$MISSING_TOOLS" = "" ] ; then
 echo -e "The following tools are missing:\n $MISSING_TOOLS"
 exit 1
fi

prepare_osx_sdk()
{
 local _PWD=$PWD
 local _TARGET=$1
 if [ ! -d $_PWD/SDKs/$OSX_SDK ] ; then
  # Download Apple SDK (from xcode 3.2.6) and source code tarballs for cctools and llvmgcc.
  [ -f xcode_3.2.6_and_ios_sdk_4.3.dmg ] || wget -c http://adcdownload.apple.com/Developer_Tools/xcode_3.2.6_and_ios_sdk_4.3__final/xcode_3.2.6_and_ios_sdk_4.3.dmg
 # Covert the xcode dmg to an img.
  [ -f xcode.img ]                       || dmg2img -v -i xcode_3.2.6_and_ios_sdk_4.3.dmg -o xcode.img
  [ -d xcode-3.2.6 ]                     || mkdir xcode-3.2.6
  mount_img xcode.img xcode-3.2.6
  # Extract the Leopard SDK (Tiger might allow for PPC builds - not that that matters these days)
  unpack_pkg xcode-3.2.6/Packages/${OSX_SDK_PKG}
  umount_img xcode.img xcode-3.2.6
 fi
 if [ ! -d $_TARGET/Developer ] ; then
  mkdir $_TARGET
  pushd $_TARGET
   mkdir Developer
   cp -R $_PWD/SDKs Developer
#   ln -sf Developer/System/Library/Frameworks Library/Frameworks
   [ -d usr ] || mkdir usr
   cp -Rf Developer/SDKs/${OSX_SDK}/usr/* usr/
  popd
#  pushd SDKs/$OSX_SDK
#   rm Library/Frameworks
#   ln -s System/Library/Frameworks Library
#   mv Developer/usr/llvm-gcc-4.2 usr
#   rm -r Developer/usr
#   ln -s usr Developer
#  popd
 fi
}

# Doesn't work; needs a lot of patching.
build_cctools_apple()
{
 [ -f cctools-809.tar.gz ] || wget -c http://www.opensource.apple.com/tarballs/cctools/cctools-809.tar.gz
 [ -d cctools-809 ]        || tar xzvf cctools-809.tar.gz
 [ -d cctools-809-build-${DARWIN_VER} ]  || cp -rf cctools-809 cctools-809-build-${DARWIN_VER}
 find cctools-809-build-${DARWIN_VER} | xargs touch
 pushd cctools-809-build-${DARWIN_VER}
 make
 make install
 popd
}

write_cctools_iphonedev_patches()
{
if [ ! -f ld64_options.patch ] ; then
cat <<EOF >> ld64_options.patch
Index: ld64/src/Options.h
===================================================================
--- ld64/src/Options.h (Revision 287)
+++ ld64/src/Options.h (Arbeitskopie)
@@ -33,6 +33,10 @@
 #include <ext/hash_set>
 #include <stdarg.h>
 
+/* mg; fixes because of header problems gcc+4.3 */
+#include <cstring>
+#include <limits.h>
+/* end of patch */
 #include "ObjectFile.h"
 
 extern void throwf (const char* format, ...) __attribute__ ((noreturn));
EOF
fi
}

# Doesn't work, xchain git repo has fixed the issues.
build_cctools_iphonedev()
{
 write_cctools_iphonedev_patches
 CCTOOLS_DIR=odcctools-9.2-ld
 if [ ! -d "${CCTOOLS_DIR}/.svn" ] || \
  ([ -d "${CCTOOLS_DIR}/.svn" ] && confirm -N "odcctools checkout exists. Checkout again?"); then
  echo "Checking out odcctools..."
  mkdir -p "${CCTOOLS_DIR}"
  svn co -r287 http://iphone-dev.googlecode.com/svn/branches/odcctools-9.2-ld "${CCTOOLS_DIR}"
  pushd "${CCTOOLS_DIR}"
   patch -p0 < ../ld64_options.patch
  popd
  # patch src/cctools/ld64/src/Options.h (#include <cstring> #include <limits.h>)
  [ -d ${CCTOOLS_DIR}-build-${DARWIN_VER} ] || cp -rf ${CCTOOLS_DIR} ${CCTOOLS_DIR}-build-${DARWIN_VER}
 fi
 pushd "${CCTOOLS_DIR}-build-${DARWIN_VER}"
  LDFLAGS="-m32" CFLAGS="-m32 -fpermissive" ./configure --prefix=$PREFIX/usr --target=$TARGET --with-sysroot=$PREFIX --enable-ld64
  make
  make install
 popd
}

# Works, but must be built in-place.
build_cctools_xchain()
{
 [ -d xchain${XCHAIN_VER}-build ] && rm -rf xchain${XCHAIN_VER}-build
 if [ ! -d xchain${XCHAIN_VER} ] ; then
  if [ "$XCHAIN_VER" = "-ma" ] ; then
   git clone https://github.com/mingwandroid/xchain.git xchain${XCHAIN_VER}
  else
   git clone https://github.com/tatsh/xchain.git xchain${XCHAIN_VER}
  fi
 fi
 cp -rf xchain xchain${XCHAIN_VER}-build-${DARWIN_VER}
 CCTOOLS_DIR=xchain${XCHAIN_VER}-build-${DARWIN_VER}/odcctools-9.2-ld
 pushd "${CCTOOLS_DIR}"
  LDFLAGS="-m32" CFLAGS="-m32 -fpermissive" ./configure --prefix=$PREFIX/usr --target=$TARGET --with-sysroot=$PREFIX --enable-ld64
  make
  make install
  # Make symlinks 'otool' and 'lipo' (as there's no Linux equivalents to cause clashes).
  pushd $PREFIX/usr/bin
   ln -sf ${TARGET}-otool otool
   ln -sf ${TARGET}-otool64 otool64
   ln -sf ${TARGET}-lipo lipo
  popd
 popd
}

build_gcc()
{
 pushd $PREFIX/usr/bin
 # If we've already made ld a link to ld64 (and backed it up as ld_classic) then undo this
 if [ -f ${TARGET}-ld_classic ] ; then
  rm -f ${TARGET}-ld
  mv ${TARGET}-ld_classic ${TARGET}-ld
 fi
 popd

 cp gcc-5666.3-t-darwin_prefix.patch xchain/patches/
 cp gcc-5666.3-strip_for_target.patch xchain/patches/
 cp gcc-5666.3-relocatable.patch xchain/patches/
 [ -f gcc-5666.3.tar.gz ] || wget -c http://opensource.apple.com/tarballs/gcc/gcc-5666.3.tar.gz
 if [ ! -d gcc-5666.3 ] ; then
  tar xvf gcc-5666.3.tar.gz
  pushd gcc-5666.3
   patch -p1 < ../xchain/patches/gcc-5666.3-cflags.patch
   patch -p1 < ../xchain/patches/gcc-5666.3-t-darwin_prefix.patch
   patch -p1 < ../xchain/patches/gcc-5666.3-strip_for_target.patch
   patch -p1 < ../xchain/patches/gcc-5666.3-relocatable.patch
  popd
 fi
 mkdir gcc-build-${DARWIN_VER}
 pushd gcc-build-${DARWIN_VER}
 CFLAGS="-m32 -O2 -msse2" CXXFLAGS="$CFLAGS" LDFLAGS="-m32" \
     ../gcc-5666.3/configure --prefix=$PREFIX/usr \
     --disable-checking \
     --enable-languages=c,objc,c++,obj-c++ \
     --with-as=$PREFIX/usr/bin/$TARGET-as \
     --with-ld=$PREFIX/usr/bin/$TARGET-ld64 \
     --target=$TARGET \
     --with-sysroot=$PREFIX \
     --enable-static \
     --enable-shared \
     --enable-nls \
     --disable-multilib \
     --disable-werror \
     --enable-libgomp \
     --with-gxx-include-dir=$PREFIX/usr/include/c++/4.2.1 \
     --with-ranlib=$PREFIX/usr/bin/$TARGET-ranlib \
     --with-lipo=$PREFIX/usr/bin/$TARGET-lipo
 make
 make install
 popd
 pushd $PREFIX/usr/bin
  ln -sf ${TARGET}-gcc ${TARGET}-gcc-4.2.1
  ln -sf ${TARGET}-g++ ${TARGET}-g++-4.2.1
 popd
}

build_llvm_gcc()
{
 # Because LLVM is the future right?
 # First, force the use of ld64 everywhere (yes you can keep this as permanent):
 pushd $PREFIX/usr/bin
 # Use the existence of ld.classic to determine whether ld is already ld64
 if [ ! -f ${TARGET}-ld_classic ] ; then
  mv ${TARGET}-ld ${TARGET}-ld_classic
  ln -sf ${TARGET}-ld64 ${TARGET}-ld
 fi
 popd

 # Need to build Apple's LLVM first.
 # This is somewhat intensive (lots of C++) so if you don't have a powerful PC do not use -j flag with make.
 [ -f llvmgcc42-2336.1.tar.gz ] || wget -c http://www.opensource.apple.com/tarballs/llvmgcc42/llvmgcc42-2336.1.tar.gz
 # Clean up because this is a two stage process and we patch between the stages.
 # rm -rf llvmgcc42-2336.1
 tar zxvf llvmgcc42-2336.1.tar.gz
 # I moved the patching to here instead of after building llvm-obj.
 cp llvmgcc42-2336.1-redundant.patch xchain/patches/
 cp llvmgcc42-2336.1-mempcpy.patch xchain/patches/
 cp llvmgcc42-2336.1-relocatable.patch xchain/patches/
 pushd llvmgcc42-2336.1
  patch -p0 < ../xchain/patches/llvmgcc42-2336.1-redundant.patch
  patch -p0 < ../xchain/patches/llvmgcc42-2336.1-mempcpy.patch
  patch -p0 < ../xchain/patches/llvmgcc42-2336.1-relocatable.patch
 popd

 mkdir llvm-obj-${DARWIN_VER}
 pushd llvm-obj-${DARWIN_VER}
  CFLAGS="-m32" CXXFLAGS="$CFLAGS" LDFLAGS="-m32" \
      ../llvmgcc42-2336.1/llvmCore/configure \
      --prefix=$PREFIX/usr \
      --enable-optimized \
      --disable-assertions \
      --target=$TARGET
  make
  make install # optional
 popd

 # Build outside the directory.
 mkdir llvmgcc-build-${DARWIN_VER}
 pushd llvmgcc-build-${DARWIN_VER}
  CFLAGS="-m32" CXXFLAGS="$CFLAGS" LDFLAGS="-m32" \
      ../llvmgcc42-2336.1/configure \
      --target=$TARGET \
      --with-sysroot=$PREFIX \
      --prefix=$PREFIX/usr \
      --enable-languages=objc,c++,obj-c++ \
      --disable-bootstrap \
      --enable--checking \
      --enable-llvm=$PWD/../llvm-obj \
      --enable-shared \
      --enable-static \
      --enable-libgomp \
      --disable-werror \
      --disable-multilib \
      --program-transform-name=/^[cg][^.-]*$/s/$/-4.2/ \
      --with-gxx-include-dir=$PREFIX/usr/include/c++/4.2.1 \
      --program-prefix=$TARGET-llvm- \
      --with-slibdir=$PREFIX/usr/lib \
      --with-ld=$PREFIX/usr/bin/$TARGET-ld64 \
      --with-tune=generic \
      --with-as=$PREFIX/usr/bin/$TARGET-as \
      --with-ranlib=$PREFIX/usr/bin/$TARGET-ranlib \
      --with-lipo=$PREFIX/usr/bin/$TARGET-lipo
  make
  make install
 popd
 pushd $PREFIX/usr/bin
  ln -sf ${TARGET}-llvm-gcc ${TARGET}-llvm-gcc-4.2
  ln -sf ${TARGET}-llvm-g++ ${TARGET}-llvm-g++-4.2
 popd
}

# There are some broken links after doing this:
# ./home/nonesuch/src/cross-mac/i686-apple-darwin9/usr/lib/gcc/i686-apple-darwin9/4.2.1/include/c++/4.0.0/powerpc-apple-darwin10: No such file or directory [../../c++/4.2.1/powerpc-apple-darwin9]
# ./home/nonesuch/src/cross-mac/i686-apple-darwin9/usr/lib/gcc/i686-apple-darwin9/4.2.1/include/c++/4.0.0/powerpc-apple-darwin8: No such file or directory
# ./home/nonesuch/src/cross-mac/i686-apple-darwin9/usr/lib/gcc/i686-apple-darwin9/4.2.1/include/c++/4.2.1/powerpc-apple-darwin10: No such file or directory
# ./home/nonesuch/src/cross-mac/i686-apple-darwin9/usr/lib/gcc/i686-apple-darwin9/4.2.1/include/c++/4.2.1/powerpc-apple-darwin8: No such file or directory
# ./home/nonesuch/src/cross-mac/i686-apple-darwin9/usr/lib/gcc/i686-apple-darwin9/4.2.1/libstdc++.dylib: No such file or directory [ -> /usr/lib/libstdc++.6.dylib]
# The powerpc ones don't matter much.

if [ "$2" = "install" -o "$2" = "install-all" ] ; then
 FINAL_INSTALL=$PWD/final-$1
 PATH=$PREFIX/usr/bin:$PATH
 [ -d $FINAL_INSTALL ] && rm -rf $FINAL_INSTALL
 mkdir -p $FINAL_INSTALL/$PREFIX
 if [ "$2" = "install-all" ] ; then
  prepare_osx_sdk $FINAL_INSTALL/$PREFIX
 fi
 pushd xchain-${DARWIN_VER}/odcctools-9.2-ld
  make DESTDIR=$FINAL_INSTALL install
 popd
 pushd gcc-build-${DARWIN_VER}
  make DESTDIR=$FINAL_INSTALL install
 popd
 pushd llvm-obj-${DARWIN_VER}
  make DESTDIR=$FINAL_INSTALL install
 popd
 pushd llvmgcc-build-${DARWIN_VER}
  make DESTDIR=$FINAL_INSTALL install
 popd
 # Remove broken links to some powerpc stuff (if we'd used 10.4, then would not want to do this)
 find $FINAL_INSTALL -name "powerpc-*" | xargs rm
 # There'll also be a broken link from $FINAL_INSTALL/$PREFIX/usr/lib/gcc/i686-apple-darwin9/4.2.1/libstdc++.dylib -> /usr/lib/libstdc++.6.dylib (ignoring libstdc++ issues for now)

 # Copy libstdc++ headers from Developer
 mkdir -p $FINAL_INSTALL/$PREFIX/usr/include/c++/4.0.0
 cp -Rf SDKs/${OSX_SDK}/usr/include/c++/4.0.0/* $FINAL_INSTALL/$PREFIX/usr/include/c++/4.0.0/
 pushd $FINAL_INSTALL/$PREFIX/usr/include/c++
  ln -s 4.0.0 4.2.1
 popd

 # Make some final links in usr/bin and make ld a link to ld64.
 pushd $FINAL_INSTALL/$PREFIX/usr/bin

  ln -sf ${TARGET}-gcc ${TARGET}-gcc-4.2.1
  ln -sf ${TARGET}-g++ ${TARGET}-g++-4.2.1

  ln -sf ${TARGET}-llvm-gcc ${TARGET}-llvm-gcc-4.2
  ln -sf ${TARGET}-llvm-g++ ${TARGET}-llvm-g++-4.2

  mv ${TARGET}-ld ${TARGET}-ld_classic
  ln -sf ${TARGET}-ld64 ${TARGET}-ld

  ln -sf ${TARGET}-otool otool
  ln -sf ${TARGET}-otool64 otool64
  ln -sf ${TARGET}-lipo lipo

  mkdir -p ../libexec/gcc
  cd ../libexec/gcc
  ln -sf ../../bin/${TARGET}-as as

 popd

 # Add an appropriate suffix so the final 7z filename clearly identifies whether it's fully open source or
 # whether it also contains proprietary Apple software. For the open-source version I should also add some
 # shell scripts to fetch and mix in the propietary parts (as without these bits it's not really useable).
 if [ $1 = "install" ] ; then
  PKGSUFFIX=open-source
 else
  PKGSUFFIX=apple-proprietary
 fi
 _PWD=$PWD
 UNAME=`uname -s`
 pushd ${FINAL_INSTALL}/${PREFIX}/..
  [ -f ${_PWD}/${TARGET}-gcc-4.2.1-llvm-gcc-4.2-${UNAME}-${PKGSUFFIX}.7z ] && rm -f ${_PWD}/${TARGET}-gcc-4.2.1-llvm-gcc-4.2-${UNAME}-${PKGSUFFIX}.7z
#  7za a -t7z -mx=9 ${_PWD}/${TARGET}-gcc-4.2.1-llvm-gcc-4.2-${UNAME}-${PKGSUFFIX}.7z ${TARGET}
 popd
 echo Final package is: ${_PWD}/${TARGET}-gcc-4.2.1-llvm-gcc-4.2-${UNAME}-${PKGSUFFIX}.7z
 exit 0

fi

prepare_osx_sdk $PREFIX

# build_cctools_apple
# build_cctools_iphonedev
# build_cctools_xchain

# exit 1

if [ $USE_CCTOOLS = "iphonedev" ] ; then
 build_cctools_iphonedev
else
 if [ $USE_CCTOOLS = "xchain" ] ; then
  build_cctools_xchain
 else
  build_cctools_apple
 fi
fi

# --with-lipo doesn't do anything for build_gcc, so must add the prefix bin folder to the path
# (and also ensure lipo exists - this is done in build_cctools_xchain)
PATH=$PREFIX/usr/bin:$PATH

# build_gcc
# build_llvm_gcc

# Test:
# export LAST=$PWD
# cd $PREFIX/usr/bin
# ln -s $TARGET-as as
# cd $LAST
# cd ..
# PATH="$PREFIX/usr/bin" $TARGET-llvm-gcc -o msg msg.m \
#     -fconstant-string-class=NSConstantString \
#     -lobjc -framework Foundation
# PATH="$PREFIX/usr/bin" $TARGET-llvm-g++ -o msgcpp msg.cpp \
#     -I$PREFIX/usr/include/c++/4.2.1

