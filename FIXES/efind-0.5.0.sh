#!/bin/bash

if [ -x /usr/bin/lsb_release ]; then
	lsb_release -a | grep -q SUSE

	if [ $? -eq 0 ]; then
		echo "Updating dependencies for OpenSUSE"
		sed "s/python3-libs/libpython3_4m1_0/" efind-0.5.0/efind.spec -i
		sed "s/libffi/libffi4/" efind-0.5.0/efind.spec -i
		sed "s/libffi4-devel/libffi-devel/" efind-0.5.0/efind.spec -i
	fi
fi
