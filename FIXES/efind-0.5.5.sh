#!/bin/bash

if [ -x /usr/bin/lsb_release ]; then
	lsb_release -a | grep -q 20.04

	if [ $? -eq 0 ]; then
		echo "Updating dependencies for Ubuntu 20.04"
		sed "s/libffi6/libffi7/" efind-0.5.5/debian/control -i
	fi
fi
