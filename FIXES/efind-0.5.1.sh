#!/bin/bash

if [ -x /usr/bin/lsb_release ]; then
	lsb_release -a | grep -q SUSE

	if [ $? -eq 0 ]; then
		echo "Updating dependencies for OpenSUSE"
		sed "s/python3-libs/libpython3_6m1_0/" efind-0.5.1/efind.spec -i
		sed "s/libffi/libffi7/" efind-0.5.1/efind.spec -i
		sed "s/libffi7-devel/libffi-devel/" efind-0.5.1/efind.spec -i
	fi
fi
