#!/bin/bash

set -e

WORKING_DIR=~/efind-build
PKG_DIR=~/efind-pkg
DOWNLOAD_URL=http://efind.dixieflatline.de/downloads/source

EFIND_TARBALL=efind-0.1.0.tar.xz
EFIND_GDKPIXBUF_TARBALL=efind-gdkpixbuf-0.1.0.tar.xz
EFIND_TAGLIB_TARBALL=efind-taglib-0.1.0.tar.xz

TARBALLS=($EFIND_TARBALL $EFIND_GDKPIXBUF_TARBALL $EFIND_TAGLIB_TARBALL)

declare -a Packages

cleanup()
{
	echo "Cleaning directory:" $WORKING_DIR

	rm $WORKING_DIR/*.* -fr
}

prepare_directories()
{
	echo "Preparing working directory:" $WORKING_DIR

	if [ ! -d $WORKING_DIR ]; then
		mkdir $WORKING_DIR
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

	cd $WORKING_DIR

	for tarball in ${TARBALLS[@]}
	do
		echo "Getting" $tarball
		wget $DOWNLOAD_URL/$tarball
	done
}

build_deb()
{
	cd $WORKING_DIR

	echo "Extracting and renaming tarball:" $1
	tar -xf $1
	orig=`echo $1 | sed -r "s/(.*)-([0-9]{1,2})\.([0-9]{1,2})\..*/\1_\2.\3.orig.tar.xz/"`
	mv $1 $orig

	echo "Building package..."
	cd ${1%.tar.xz}
	dpkg-buildpackage -uc -us
	debfile=`cat debian/files | cut -d" " -f1`

	cd $WORKING_DIR
	echo "Moving package to" $PKG_DIR
	mv $debfile $PKG_DIR/

	Packages=(${Packages[@]} $debfile)
}

build_rpm()
{
	cd $WORKING_DIR

	echo "Copying source file:" $1
	cp $1 ~/rpm/SOURCES

	echo "Extracting tarball:" $1
	tar -xf $1

	specfile=`ls ${1%.tar.xz}/*.spec`
	echo "Copying spec file:" $specfile
	cp $specfile ~/rpm/SPECS/

	echo "Building rpm..."
	cd ~/rpm
	if [ -x /usr/bin/lsb_release ]; then
		lsb_release -a | grep -q SUSE

		if [ $? -eq 0 ]; then
			echo "Updating dependencies for OpenSUSE"

			if [ $(basename $specfile) == "efind-gdkpixbuf.spec" ]; then
				sed "s/gdk-pixbuf2/gdk-pixbuf/" SPECS/efind-gdkpixbuf.spec -i
			fi
		fi
	fi

	rpmbuild -ba SPECS/`basename $specfile`

	echo "Moving package to" $PKG_DIR
	rpmfile=~/rpm/RPMS/`arch`/`echo $1 | sed "s/.tar.xz/*.rpm/"`
	mv $rpmfile $PKG_DIR

	Packages=(${Packages[@]} `basename $rpmfile`)
}

build_txz()
{
	cd $WORKING_DIR

	sb=./${1%.tar.xz}/SlackBuild
	testdir=./${1%.tar.xz}/test

	echo "Extracting SlackBuild:" $1
	tar -xf $1 $sb $testdir

	echo "Moving tarball to SlackBuild folder" $sb
	mv $1 $sb

	echo "Running SlackBuild script..."
	cd $sb
	sudo sh ./*.SlackBuild

	echo "Moving package to" $PKG_DIR
	txz=${1%.tar.xz}-$(arch)*_bbsb.txz

	sudo mv /tmp/$txz $PKG_DIR/

	echo "Changing ownership:" $username":"$group
	username=`id -un`
	group=`id -gn`
	sudo chown $username:$group $PKG_DIR/$txz

	Packages=(${Packages[@]} $txz)
}

build_pkg()
{
	cd $WORKING_DIR

	build=./${1%.tar.xz}
	testdir=./${1%.tar.xz}/test

	echo "Extracting PKGBUILD and test directory from" $1
	tar -xf $1 $build/PKGBUILD $testdir

	echo "Moving tarball to build folder" $build
	cp $1 $build

	cd $build

	echo "Updating MD5 sum"
	chk=$(md5sum $1 | cut -d' ' -f1)
	sed -r "s/md5sums=\(''\)/md5sums=\('$chk'\)/" PKGBUILD -i

	echo "Building package..."
	makepkg

	echo "Moving package to" $PKG_DIR
	pkg=${1%.tar.xz}-*.pkg.tar.xz
	mv $pkg $PKG_DIR

	Packages=(${Packages[@]} $pkg)
}

build_package()
{
	if [ -f /etc/slackware-version ]; then
		build_txz $tarball
	elif [ -f /etc/arch-release ]; then
		build_pkg $tarball
	elif [ -x /usr/bin/dpkg-buildpackage ]; then
		build_deb $tarball
	elif [ -x /usr/bin/rpmbuild ]; then
		build_rpm $tarball
	fi
}

install_packages()
{
	if [ -f /etc/slackware-version ]; then
		for pkg in ${Packages[@]}
		do
			sudo installpkg $PKG_DIR/$pkg
		done
	elif [ -f /etc/arch-release ]; then
		for pkg in ${Packages[@]}
		do
			sudo pacman -U $PKG_DIR/$pkg
		done
	elif [ -x /usr/bin/dpkg ]; then
		for pkg in ${Packages[@]}
		do
			sudo dpkg -i $PKG_DIR/$pkg
		done
	elif [ -x /bin/rpm ]; then
		for pkg in ${Packages[@]}
		do
			sudo rpm -i $PKG_DIR/$pkg
		done
	fi
}

run_test()
{
	cd $WORKING_DIR/${1%.tar.xz}/test
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
