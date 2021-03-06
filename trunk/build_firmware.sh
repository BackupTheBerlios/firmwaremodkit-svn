#!/bin/sh
. "./shared.inc"
VERSION='0.51 beta'
#
# Title: build_firmware.sh
# Author: Jeremy Collake <jeremy.collake@gmail.com>
# Site: http://www.bitsum.com/firmware_mod_kit.htm
#
# Script to build a cybertan format firmware
# with a squashfs-lzma filesystem.
#
# See documentation at:
#  http://www.bitsum.com/firmware_mod_kit.htm
#
# USAGE: build_firmware.sh OUTPUT_DIRECTORY/ WORKING_DIRECOTRY/
#
# This scripts builds the firmware image from [WORKING_DIRECTORY],
# with the following subdirectories:
#
#    image_parts/   <- firmware seperated
#    rootfs/ 	    <- filesystem
#
# Example:
#
# ./build_firmware.sh new_firmwares/ std_generic/
#
#
FIRMARE_BASE_NAME=custom_image
EXIT_ON_FS_PROBLEM="0"

echo "$0 v$VERSION, (c)2006-2008 Jeremy Collake. Please consider donating."

#################################################################
# InvokeTRX ( OutputDir, WorkingDir, filesystem image filename )
#################################################################
InvokeTRX ()
{
	echo "  Building base firmware image (generic) ..."	
	SEGMENT_1="$2/image_parts/segment1"
	if [ -f "$2/image_parts/segment2" ]; then
		SEGMENT_2="$2/image_parts/segment2"
	else
		SEGMENT_2=""
	fi
	# I switched to asustrx due to bug in trx with big endian OS X.
	#  it works just like trx if you don't supply a version number (skips addver appendage)
	"src/asustrx" -o "$1/$FIRMARE_BASE_NAME.trx" \
		$SEGMENT_1 $SEGMENT_2 \
		"$2/image_parts/$3" \
			>> build.log 2>&1
	echo "  Building base firmware image (asus) ..."	
	"src/asustrx" -p WL500gx -v 1.9.2.7 -o "$1/$FIRMARE_BASE_NAME-asus.trx" \
		$SEGMENT_1 $SEGMENT_2 \
		"$2/image_parts/$3" \
		 >> build.log 2>&1

}

#################################################################
# CreateTargetImages ( OutputDir, WorkingDir )
#
# addpattern (HDR0) images. Maybe other model specific stuff
# later.
#################################################################
CreateTargetImages ()
{
	echo "  Making $1/$FIRMARE_BASE_NAME-wrtsl54gs.bin"
	if [ ! -f "$1/$FIRMARE_BASE_NAME.trx" ]; then
		echo "  ERROR: Sanity check failed."
		exit 1
	fi
	"src/addpattern" -4 -p W54U -v v4.20.6 -i "$1/$FIRMARE_BASE_NAME.trx" \
		 -o "$1/$FIRMARE_BASE_NAME-wrtsl54gs.bin" -g >> build.log 2>&1
	echo "  Making $1/$FIRMARE_BASE_NAME-wrt54g.bin"
	"src/addpattern" -4 -p W54G -v v4.20.6 -i "$1/$FIRMARE_BASE_NAME.trx" \
		-o "$1/$FIRMARE_BASE_NAME-wrt54g.bin" -g >> build.log 2>&1
	echo "  Making $1/$FIRMARE_BASE_NAME-wrt54gs.bin"
	"src/addpattern" -4 -p W54S -v v4.70.6 -i "$1/$FIRMARE_BASE_NAME.trx" \
		-o "$1/$FIRMARE_BASE_NAME-wrt54gs.bin" -g >> build.log 2>&1
	echo "  Making $1/$FIRMARE_BASE_NAME-wrt54gsv4.bin"
	"src/addpattern" -4 -p W54s -v v1.05.0 -i "$1/$FIRMARE_BASE_NAME.trx" \
		-o "$1/$FIRMARE_BASE_NAME-wrt54gsv4.bin" -g >> build.log 2>&1
	echo "  Making $1/$FIRMARE_BASE_NAME-generic.bin"
	ln -s "$1/$FIRMARE_BASE_NAME.trx" "$1/$FIRMARE_BASE_NAME-generic.bin" >> build.log 2>&1
}

#################################################################
# Build_WRT_Images( OutputDir, WorkingDir )
#################################################################
Build_WRT_Images ()
{
	echo "  Building squashfs-lzma filesystem ..."
	if [ -e "$2/image_parts/squashfs-lzma-image-3_0" ]; then	
		# -magic to fix brainslayer changing squashfs signature in 08/10/06+ firmware images
	 	"src/squashfs-3.0/mksquashfs-lzma" "$2/rootfs/" "$2/image_parts/squashfs-lzma-image-new" \
		-noappend -root-owned -le -magic "$2/image_parts/squashfs_magic" >> build.log
		if [ $? != 0 ]; then
			echo "  ERROR - mksquashfs failed."
			exit 1	
		fi
	else
		echo "  ERROR - Working directory contains no sqfs filesystem?"
		exit 1
	fi	
	#################################################################
	InvokeTRX "$1" "$2" "squashfs-lzma-image-new"
	CreateTargetImages "$1" "$2" 	
}

#################################################################
# MakeCramfs (output file, root dir)
#
# invokes mkcramfs
#
#################################################################
MakeCramfs ()
{
	echo "  Building cramfs file system ..."
	./src/cramfs-2.x/mkcramfs "$2" "$1" >> build.log 2>&1
	if [ $? != 0 ]; then
		echo "  ERROR: creating cramfs file system failed.".
		exit "$?"
	else
		echo "  Successfully created cramfs image."
	fi
}

#################################################################
# Build_WL530G_Image (OutputDir, WorkingDir, fs image filename [only] )
#
# Builds an ASUS WL530/520/550G image.
#
#################################################################
Build_WL530G_Image ()
{
	echo "  Building wl-530/520/550g style image (static TRX offsets)."
	./src/asustrx -p WL530g -v 1.9.4.6 -o "$1/$FIRMARE_BASE_NAME-wl530g.trx" -b 32 "$2/image_parts/segment1" -b 655360 "$2/image_parts/$3"  >> build.log 2>&1	
}


#################################################################
#################################################################
#################################################################

if [ $# = 2 ]; then
	sh ./check_for_upgrade.sh
	#################################################################
	PlatformIdentify 
	#################################################################
	TestFileSystemExit "$1" "$2"
	#################################################################
	if [ ! -f "./build_firmware.sh" ]; then
		echo "  ERROR - You must run this script from the same directory as it is in!"
		exit 1
	fi
	#################################################################
	# remove deprecated stuff
	if [ -f "./src/mksquashfs.c" ] || [ -f "mksquashfs.c" ]; then
		DeprecateOldVersion
	fi
	#################################################################
	# Invoke BuildTools, which tries to build everything and then
	# sets up appropriate symlinks.
	#
	BuildTools "build.log"
	#################################################################
	echo "  Preparing output directory $1 ..."
	mkdir -p $1 >> build.log 2>&1
	rm "$1/$FIRMWARE_BASE_NAME*.*" "$1" >> build.log 2>&1
	
	if [ -f "$2/image_parts/segment2" ] && [ -f "$2/image_parts/squashfs-lzma-image-3_0" ]; then
		echo "  Detected WRT squashfs-lzma style."
		Build_WRT_Images "$1" "$2"
	elif [ -f "$2/image_parts/cramfs-image-x_x" ]; then
		echo "  Detected cramfs file system."
		TestIsRootAndExitIfNot
		# remove old filename of new image..
		rm -f "$2/image_parts/cramfs-image-1.1"
		MakeCramfs "$2/image_parts/cramfs-image-new" "$2/rootfs"
		# todo: rewrite this terrible test
		grep "530g" "$2/image_parts/cramfs-image-x_x" >> build.log 2>&1				
		if [ $? = "0" ]; then
			IS_530G_STYLE=1
		fi
		grep "550g" "$2/image_parts/cramfs-image-x_x" >> build.log 2>&1			
		if [ $? = "0" ]; then
			IS_530G_STYLE=1
		fi
		grep "520g" "$2/image_parts/cramfs-image-x_x" >> build.log 2>&1		
		if [ $? = "0" ]; then
			IS_530G_STYLE=1
		fi
		if [ "$IS_530G_STYLE" = "1" ]; then		
			Build_WL530G_Image "$1" "$2" "cramfs-image-new"
		else
			echo "  No specific firmware type known, so am making standard images."
			InvokeTRX "$1" "$2" "cramfs-image-new"
			CreateTargetImages "$1" "$2"			
		fi 
	else		
		echo "  ERROR: Unknown or unsupported firmware image."
		exit 1
	fi

	echo "  Firmware images built."
	ls -l "$1"
	echo "  All done!"
else
	#################################################################
	echo "  Incorrect usage."
	echo "  USAGE: $0 OUTPUT_DIR WORKING_DIR"
	exit 1
fi
exit 0
