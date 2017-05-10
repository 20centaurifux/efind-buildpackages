#!/bin/bash
#
#  efind-buildpackages
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License v3 as published by
#  the Free Software Foundation.
#
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License v3 for more details.
#  efind test suite.
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License v3 as published by
#  the Free Software Foundation.
#
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License v3 for more details.

set -e

WORKING_DIR=~/efind-build
PKG_DIR=~/efind-pkg
RUN_PATH=$PWD
RPMBUILD_PATH=~/rpm

declare -a Available
declare -a Install
declare -a Packages
declare Platform=''

die()
{
	echo $1 && exit 1
}

detect_platform()
{
	if [ -f /etc/slackware-version ]; then
		Platform=txz
	elif [ -f /etc/arch-release ]; then
		Platform=arch
	elif [ -x /usr/bin/dpkg-buildpackage ]; then
		Platform=dpkg
	elif [ -x /usr/bin/rpmbuild ]; then
		Platform=rpm
	else
		die "Couldn't detect platform."
	fi
}

load_sources()
{
	while read -r tarball
	do
		Available=(${Available[@]} $tarball)
	done < SOURCES
}

select_sources()
{
	local -a options
	local i=1

	for src in ${Available[@]}
	do
		options=(${options[@]} $i $(basename $src) on)
		i=$((i+1))
	done

	local cmd=(dialog --separate-output --checklist "Please select the sources you want to build" 16 80 16)
	local choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

	for choice in $choices
	do
		Install=(${Install[@]} ${Available[((choice-1))]})
	done
}

prepare_directories()
{
	echo "Preparing working directory:" $WORKING_DIR

	if [ ! -d $WORKING_DIR ]; then
		mkdir $WORKING_DIR
	else
		rm $WORKING_DIR/* -fr
	fi

	echo "Testing package directory:" $PKG_DIR

	if [ ! -d $PKG_DIR ]; then
		mkdir $PKG_DIR
	else
		rm $PKG_DIR/* -fr
	fi
}

download_tarball()
{
	local tarball=$1

	echo "Downloading sources:" $tarball
	cd $WORKING_DIR && wget $tarball
}

extract_tarball()
{
	local tarball=$1

	echo "Extracting tarball:" $tarball

	cd $WORKING_DIR
	tar -xf $tarball

	local fix=$RUN_PATH/FIXES/${tarball%.tar.xz}.sh

	if [ -x $fix ]; then
		echo "Running fix:" $fix
		$fix
	fi
}

build_deb()
{
	cd $WORKING_DIR

	local tarball=$1

	echo "Copying tarball..." $tarball
	local orig=`echo $tarball | sed -r "s/(.*)-([0-9]{1,2})\.([0-9]{1,2})\..*/\1_\2.\3.orig.tar.xz/"`
	cp $tarball $orig
	echo "Tarball copied successfully:" $orig

	echo "Building package..."
	cd ${tarball%.tar.xz}
	dpkg-buildpackage -uc -us
	local debfile=`cat debian/files | cut -d" " -f1`

	cd $WORKING_DIR
	echo "Moving package to" $PKG_DIR
	mv $debfile $PKG_DIR/

	Packages=(${Packages[@]} $debfile)
}

build_rpm()
{
	cd $WORKING_DIR

	local tarball=$1

	echo "Copying source file:" $tarball
	cp $tarball $RPMBUILD_PATH/SOURCES

	local specfile=$(ls -1 ${tarball%.tar.xz}/*.spec)
	echo "Copying spec file:" $specfile
	cp $specfile $RPMBUILD_PATH/SPECS/

	echo "Building rpm..."
	cd $RPMBUILD_PATH
	rpmbuild -ba SPECS/$(basename $specfile)

	echo "Moving package to" $PKG_DIR
	local rpmfile=$(ls -1 $RPMBUILD_PATH/RPMS/$(arch)/$(echo $tarball | sed "s/.tar.xz/*.$(arch).rpm/"))
	mv $rpmfile $PKG_DIR

	Packages=(${Packages[@]} $(basename $rpmfile))
}

build_txz()
{
	cd $WORKING_DIR

	local tarball=$1
	local sb=./${tarball%.tar.xz}/SlackBuild

	echo "Moving tarball to SlackBuild folder" $sb
	mv $tarball $sb

	echo "Running SlackBuild script..."
	cd $sb
	sudo sh ./*.SlackBuild

	echo "Moving package to" $PKG_DIR
	local txz=$(basename $(ls -1 /tmp/${tarball%.tar.xz}-$(arch)*_bbsb.txz))

	sudo mv /tmp/$txz $PKG_DIR/

	local username=`id -un`
	local group=`id -gn`

	echo "Changing ownership:" $username":"$group
	sudo chown $username:$group $PKG_DIR/$txz

	Packages=(${Packages[@]} $txz)
}

build_pkg()
{
	cd $WORKING_DIR

	local tarball=$1
	local build=./${tarball%.tar.xz}

	echo "Copying tarball to build folder" $build
	cp $tarball $build

	echo "Updating MD5 sum"
	cd $build
	local chk=$(md5sum $tarball | cut -d' ' -f1)
	sed -r "s/md5sums=\(''\)/md5sums=\('$chk'\)/" PKGBUILD -i

	echo "Building package..."
	makepkg

	echo "Moving package to" $PKG_DIR
	local pkg=`ls -1 ${tarball%.tar.xz}-*.pkg.tar.xz`
	mv $pkg $PKG_DIR

	Packages=(${Packages[@]} $pkg)
}

build_package()
{
	local tarball=$1

	echo "Building package..."

	case $Platform in
		arch) cmd=build_pkg
		;;

		txz) cmd=build_txz
		;;

		rpm) cmd=build_rpm
		;;

		dpkg) cmd=build_deb
		;;
	esac

	extract_tarball $tarball && $cmd $tarball
}

run_test_suite()
{
	local pkg=$1
	local testdir=$2

	set +e
	dialog --title "Run test suite" --backtitle "$pkg" --yesno "Do you want to run the test-suite of the installed package?" 7 70
	local result=$?
	set -e

	if [ $result -eq 0 ]; then
		echo "Running test-suite in directory" $testdir
		cd $testdir && ./run.sh

		echo -n "[Press any key to continue]"
		read -s -n1
	fi
}

install_package()
{
	local pkg=$1
	local tarball=$2

	set +e
	dialog --title "Install package" --backtitle "$1" --yesno "Do you want to install the package '$1' on your system?" 7 70
	local result=$?
	set -e

	if [ $result -eq 0 ]; then
		case $Platform in
			arch) cmd=(pacman -U --noconfirm)
			;;

			txz) cmd=(/sbin/installpkg)
			;;

			rpm) cmd=(rpm -i --replacepkgs)
			;;

			dpkg) cmd=(dpkg -i)
			;;
		esac

		sudo ${cmd[@]} $PKG_DIR/$pkg

		local testdir=$WORKING_DIR/${tarball%.tar.xz}/test

		if [ -d $testdir ] && [ -x $testdir/run.sh ]; then
			run_test_suite $pkg $testdir
		fi
	fi
}

run_post_processing_scripts()
{
	local -a options
	local i=1

	for script in `ls -1 $RUN_PATH/AFTER`
	do
		if [ -x $RUN_PATH/AFTER/$script ]; then
			options=(${options[@]} $i $script on)
			i=$((i+1))
		fi
	done

	if [ ${#options[@]} -ne 0 ]; then
		local cmd=(dialog --separate-output --checklist "Please select the post-processing scripts you want to run:" 16 60 16)
		local choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)

		set +e

		for choice in $choices
		do
			local script=${options[((choice-1))*3+1]}
			local cmd="$RUN_PATH/AFTER/$script"
			local -a files

			for file in ${Packages[@]}; do
				files=(${files[@]} "$PKG_DIR/$file")
			done

			$cmd "${files[@]}"

			if [ $? -ne 0 ]; then
				dialog --title "Post processing" --backtitle "$script" --yesno "Script failed, do you want to continue?" 7 60

				if [ $? -ne 0 ]; then
					break
				fi
			fi
		done

		set -e
	fi
}

build_and_install_packages()
{
	for tarball in ${Install[@]}; do
		local name=$(basename $tarball)

		download_tarball $tarball
		build_package $name
		install_package ${Packages[-1]} $name
	done

	if [ ${#Packages[@]} -ne 0 ]; then
		run_post_processing_scripts
	fi
}

detect_platform && load_sources && select_sources

if [ ${#Install[@]} -ne 0 ]; then
	prepare_directories
	build_and_install_packages
	dialog --msgbox "Build finished." 7 20 && clear
fi
