#!/bin/bash

if [ -x /usr/bin/lsb_release ]; then
	lsb_release -a | grep -q Ubuntu

	if [ $? -eq 0 ]; then
		echo "Updating dependencies for Ubuntu"
		sed "s/libffi6/libffi8/" efind-0.5.9/debian/control -i
	fi
fi
