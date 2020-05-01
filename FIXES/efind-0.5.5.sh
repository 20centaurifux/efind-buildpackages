#!/bin/bash

if [ -x /usr/bin/lsb_release ]; then
	lsb_release -a | grep -q 20.04

	if [ $? -eq 0 ]; then
		echo "Updating dependencies for Ubuntu 20.04"
		sed "s/libffi6/libffi7/" efind-0.5.5/debian/control -i
	fi

	lsb_release -a | grep -q SUSE

	if [ $? -eq 0 ]; then
		echo "Updating dependencies for OpenSUSE"
		sed "s/python3-libs/libpython3_6m1_0/" efind-0.5.5/efind.spec -i
		sed "s/libffi/libffi7/" efind-0.5.5/efind.spec -i
		sed "s/libffi7-devel/libffi-devel/" efind-0.5.5/efind.spec -i
	fi
fi
