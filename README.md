Based on original documentation by OpenTTD team [Link](http://devs.openttd.org/~truebrain/compile-farm/apple-darwin9.txt)

With these files you may build odcctools and GCC 4.2.1 targetting iOS running on POSIX
(tested on Ubuntu Linux 12.04).

This has been tested on iOS 4.2.1 on iPhone 3G and iOS 5.1.1 on iPad 3.

How to build:

    export TARGET=arm-apple-darwin
    export PREFIX=/usr/$TARGET
    mkdir $PREFIX
    cd $PREFIX

In ~/.bashrc or similar you may want:

    export DARWIN_PREFIX=<prefix you chose>

# Prepare your prefix

If you don't have a Mac, skip this and read 'Prepare your prefix (no Mac)'. Even if you have a Mac, the no-Mac method is cleaner than using scp but not as easy.

You will need a copy of an SDK directory to begin. You can choose any version past 10.4u really but I suppose only if you need new things in Lion would copy Lion's SDK (and that requires Lion itself of course). I expect that you are doing most development on the Mac anyway so therefore your compiler settings in Xcode will decide support level.

    mkdir $PREFIX/SDKs
    cd $PREFIX/SDKs

If you have Snow Leopard:

    export SDK=MacOSX10.6.sdk
    scp -r myname@mymac:/Developer/SDKs/$SDK .

If you have Lion (and want latest headers):

    export SDK=MacOSX10.7.sdk
    scp -r myname@mymac:/Developer/SDKs/$SDK .

# Prepare your prefix (no Mac)

If you are copying from Mac with scp, skip to 'Continue with scp'.

Download the DMG from Apple for Xcode, any version. You need to have the following:

* Linux kernel built with HFS+ file system driver
* p7zip
* xar
* tar, gzip, bzip2
* cpio

Use `mount` and `umount` as root or with `sudo` (probably easier with `sudo`):

    7z x xcode_4.2_and_ios_5_sdk_for_snow_leopard.dmg # should work with any other version
    
    sudo mkdir /media/dmg
    sudo mount -t hfsplus -o loop 5.hfs /media/dmg
    
    pushd $PREFIX
    sudo mkdir SDKs
    cd SDKs
    sudo cp /media/dmg/Packages/iPhoneSDK4_3.pkg ./
    sudo /path/to/xchain-ios/extractpkg.sh iPhoneSDK4_3.pkg
    sudo mv Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS4.3.sdk ./
    sudo rm -r iPhoneSDK4_3.pkg Payload Platforms usr
    sudo umount /media/dmg

You will now have an SDKs directory, but it needs fixing.

    cd iPhoneOS4.3.sdk
    sudo ln -s Sysem/Library Library
    cd ..
    sudo ln -s SDKs/iPhoneOS4.3.sdk/* ./
    popd

If you used the no-Mac method, skip to 'Building cctools'.

# Building cctools

You really should only apply the patch if you are not on OS X/Darwin, because I have not tested any of this on OS X/Darwin yet.

    wget http://opensource.apple.com/tarballs/cctools/cctools-806.tar.gz
    tar xvf cctools-806.tar.gz
    patch -p0 < patches/cctools-806-nondarwin.patch
    cd cctools-806
    chmod +x configure
    CFLAGS="-m32" LDFLAGS="-m32" ./configure --prefix=$PREFIX/usr --target=$TARGET --with-sysroot=$PREFIX
    make
    sudo make install
    cd ..

Note `-m32`. Everything will be 32-bit. Building for 64-bit is not supported (but using 32-bit to build 64-bit binaries is). Do not try optimisation flags. `ranlib` is especially sensitive.

Ignore ALL warnings. There will be many (or you can use `-w` for a `CFLAG`).

# Building ld64

To build GCC we cannot use what's known as 'classic' `ld`. We have to use `ld64` (even though we are not going to build it in 64-bit mode). For the moment, use odcctools-9.2 from the iphone-dev project (the version in this repository is patched for GCC 4.5):

    cd odcctools-9.2-ld
    CFLAGS="-m32" LDFLAGS="-m32" ./configure --prefix=$PREFIX/usr --target=$TARGET --with-sysroot=$PREFIX --enable-ld64
    make
    cd ld64
    make install
    cd ../..

Do not try optimisation flags here either.

When making in the cctools-806 and odcctools-9.2-ld directory, there may be errors.
You can fix them by adding the appropriate declarations (structs and enums) to
`mach-o/arm/reloc.h` and `mach-o/loader.h`, and/or commenting out as many function
declarations as needed in `include/stuff/bytesex.h`

Export `$PATH` to have your new tools. You may want to add this to your `~/.bashrc` or similar.

    export PATH="$PATH:/usr/$TARGET/usr/bin"

# Building LLVM-GCC

Because LLVM is the future right? Anyways, the iOS toolchain works only with LLVM-GCC.

First, force the use of ld64 everywhere (yes you can keep this as permanent):

    pushd $PREFIX/usr/bin
    mv $TARGET-ld $TARGET-ld.classic
    ln -s $TARGET-ld64 $TARGET-ld
    popd

You need to build Apple's LLVM-core itself first.

    wget http://opensource.apple.com/tarballs/llvmgcc42/llvmgcc42-2335.15.tar.gz
    tar xvf llvmgcc42-2335.15.tar.gz
    mkdir llvm-obj
    cd llvm-obj
    CFLAGS="-m32" CXXFLAGS="$CFLAGS" LDFLAGS="-m32" \
        ../llvmgcc42-2335.15/llvmCore/configure \
        --prefix=$PREFIX/usr \
        --enable-optimized \
        --disable-assertions \
        --target=$TARGET
    make
    sudo make install
    cd ..

This is somewhat intensive (lots of C++) so if you don't have a powerful PC do not use `-j` flag with `make`.
Here also may be errors complaining about something like `ptrdiff_t doesn't name a type` or
`NULL was not declared in this scope`. Solution:
find the file which the compiler error describes, and insert

    #include <cstddef>
    
somewhere at the top of the file, among the other includes. This file contains the declaration
of both `ptrdiff_t` and `NULL`.

Next, proceed to build GCC itself, but you need to patch one thing (at least needed GCC 4.5 and 4.6):

    cd llvmgcc42-2335.15
    patch -p0 < ../patches/llvmgcc42-2335.15-redundant.patch
    patch -p0 < ../patches/llvmgcc42-2335.15-mempcpy.patch
    cd ..

Build outside the directory.

    mkdir llvmgcc-build
    cd llvmgcc-build
    ../llvmgcc42-2335.15/configure \
        --target=$TARGET \
        --with-sysroot=$PREFIX \
        --prefix=$PREFIX/usr \
        --enable-languages=c,c++,objc,obj-c++ \
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
        --with-as=$PREFIX/usr/bin/$TARGET-as \
        --with-ranlib=$PREFIX/usr/bin/$TARGET-ranlib \
        --with-lipo=$PREFIX/usr/bin/$TARGET-lipo \
        --with-ar=$PREFIX/usr/bin/$TARGET-ar \
        --enable-sjlj-exceptions
    make
    sudo make install

Then will fix g++:

    cd $PREFIX/usr/lib
    ln -s libgcc_s.1.dylib libgcc_s.10.4.dylib

This will make it a little more sane:

    cd $PREFIX/usr/bin
    ln -s arm-apple-darwin-gcc-4.2.1 arm-apple-darwin-gcc
    ln -s arm-apple-darwin-llvm-g++ arm-apple-darwin-g++

You will have a working compiler targetting iOS. You need a jailbroken phone before any code will run. Works for me.

Try:

    ssh root@My_iPhone uname -a
    arm-apple-darwin-g++ -o msg.arm msg.cpp \
        -I$PREFIX/usr/include/c++/4.2.1 \
        -I$PREFIX/usr/include/c++/4.2.1/armv6-apple-darwin10
    # Fake codesign if needed:
    # ldid -S msg.arm
    scp msg.arm root@My_iPhone:
    ssh root@My_iPhone ./msg.arm

Output:

    Darwin My_iPhone 11.0.0 Darwin Kernel Version 11.0.0: Wed Mar 30 18:51:10 PDT 2011; root:xnu-1735.46~10/RELEASE_ARM_S5L8930X iPhone3,1 arm N90AP Darwin
    This was compiled on a non-Mac!

Note that you need both of those include path arguments. Yes, it's an ongoing issue.

You can copmile Objective-C(++) too:

    arm-apple-darwin-gcc -o msg2.arm msg.m -lobjc -framework Foundation

Also note that the minimum version to run any code is iOS 3.0 by default. To get 2.0 support for example, use `-miphoneos-version-min=2.0` in your line:

    arm-apple-darwin-g++ -o msg.o -c msg.cpp \
        -I$PREFIX/usr/include/c++/4.2.1 \
        -I$PREFIX/usr/include/c++/4.2.1/armv6-apple-darwin10 \
        -miphoneos-version-min=2.0

Also note that these are not univeral binaries, even if you use `-force_cpusubtype_ALL`. These are armv6.

# Generate fat binary

Compile both architectures:

    export TARGET=x86_64-apple-darwin11
    $TARGET-g++ -o msg.x86_64 -I$PREFIX/usr/include/c++/4.2.1
    export TARGET=arm-apple-darwin
    $TARGET-g++ -o msg.arm \
        -I$PREFIX/usr/include/c++/4.2.1 \
        -I$PREFIX/usr/include/c++/4.2.1/armv6-apple-darwin10

Now use lipo from any of the architectures you have built:

    $TARGET-lipo x86_64-apple-darwin11-lipo -create -arch arm msg.arm -arch x86_64 msg.x86_64 -output msg

Testing on iPhone:

    scp msg root@My_iPhone:
    ssh root@My_iPhone ./msg

Output:

    This was compiled on a non-Mac!

Get info from a mac:

    scp msg myname@mymac
    ssh myname@mymac lipo -detailed_info msg
    
Output:

    Fat header in: msg
    fat_magic 0xcafebabe
    nfat_arch 2
    architecture arm
        cputype CPU_TYPE_ARM
        cpusubtype CPU_SUBTYPE_ARM_ALL
        offset 4096
        size 13052
        align 2^12 (4096)
    architecture x86_64
        cputype CPU_TYPE_X86_64
        cpusubtype CPU_SUBTYPE_X86_64_ALL
        offset 20480
        size 9288
        align 2^12 (4096)

# Todo

* Fix paths when invoked (sysroot issue, maybe `--with-gxx-include-dir` will fix):
  * Double search paths for C++: `/home/tatsh/usr/x86_64-apple-darwin11/home/tatsh/usr/x86_64-apple-darwin11/usr/x86_64-apple-darwin11/include/c++/4.2.1/x86_64-apple-darwin11`
* `ld` warnings about arch maybe
* distcc for Objective-C and C++
* distcc with MacPorts
* Get latest cctools to build on Linux (DONE except for cbtlibs, efitools, gprof; these are probably unnecessary)
* Clang
* HOWTO generate .app directory, plist, Resources, etc (nib files and CoreData impossible without Mac?)
* Provide even more patch files to avoid compiler errors

