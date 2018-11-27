#!/bin/bash

if [ -x /usr/bin/lsb_release ]; then
	lsb_release -a | grep -q SUSE

	if [ $? -eq 0 ]; then
		echo "Updating dependencies for OpenSUSE"
		sed "s/taglib-devel/libtag-devel/" efind-taglib-0.2.0/efind-taglib.spec -i
	fi
fi
