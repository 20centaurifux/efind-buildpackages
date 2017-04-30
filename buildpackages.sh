#!/bin/bash

set -e

WORKKING_DIR=~/efind-build
PKG_DIR=~/efind-pkg
DOWNLOAD_URL=http://efind.dixieflatline.de/downloads/source

EFIND_TARBALL=efind-0.1.0.tar.xz
EFIND_GDKPIXBUF_TARBALL=efind-gdkpixbuf-0.1.0.tar.xz
EFIND_TAGLIB_TARBALL=efind-taglib-0.1.0.tar.xz

TARBALLS=($EFIND_TARBALL $EFIND_GDKPIXBUF_TARBALL $EFIND_TAGLIB_TARBALL)

declare -a Packages

cleanup()
{
	echo "Cleaning directory:" $WORKKING_DIR

	rm $WORKKING_DIR/*.* -fr
}

prepare_directories()
{
	echo "Preparing working directory:" $WORKKING_DIR

	if [ ! -d $WORKKING_DIR ]; then
		mkdir $WORKKING_DIR
	fi

	echo "Testing package directory:" $PKG_DIR

	if [ ! -d $PKG_DIR ]; then
		mkdir $PKG_DIR
	fi

	cleanup
}

download_tarballs()
{
	echo "Downloading tarballs..."

	cd $WORKKING_DIR

	for tarball in ${TARBALLS[@]}
	do
		echo "Getting" $tarball
		wget $DOWNLOAD_URL/$tarball
	done
}

build_deb()
{
	cd $WORKKING_DIR

	echo "Extracting and renaming tarball:" $1
	tar -xf $1
	orig=`echo $1 | sed -r "s/(.*)-([0-9]{1,2})\.([0-9]{1,2})\..*/\1_\2.\3.orig.tar.xz/"`
	mv $1 $orig

	echo "Building package..."
	cd ${1%.tar.xz}
	dpkg-buildpackage -uc -us
	debfile=`cat debian/files | cut -d" " -f1`

	cd $WORKKING_DIR
	echo "Moving package to" $PKG_DIR
	mv $debfile $PKG_DIR/
	Packages=(${Packages[@]} $debfile)
}

build_package()
{
	if [ -x /usr/bin/dpkg-buildpackage ]; then
		build_deb $tarball
	fi
}

install_packages()
{
	if [ -x /usr/bin/dpkg ]; then
		for pkg in ${Packages[@]}
		do
			sudo dpkg -i $PKG_DIR/$pkg
		done
	fi
}

run_test()
{
	echo "Running test-suite..."

	cd $WORKKING_DIR/${1%.tar.xz}/test
	./run.sh
}

prepare_directories && download_tarballs

for tarball in ${TARBALLS[@]}
do
	build_package $tarball
done

read -p "Install built packages (y/n)?" choice

if [ $choice == "y" ]; then
	install_packages

	read -p "Run tests (y/n)?" choice

	if [ $choice == "y" ]; then
		for tarball in ${TARBALLS[@]}
		do
			run_test $tarball
		done
	fi
fi
