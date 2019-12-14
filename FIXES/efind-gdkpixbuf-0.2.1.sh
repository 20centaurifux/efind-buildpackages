#!/bin/bash

if [ -x /usr/bin/lsb_release ]; then
	lsb_release -a | grep -q SUSE

	if [ $? -eq 0 ]; then
		echo "Updating dependencies for OpenSUSE"
		sed "s/gdk-pixbuf2/gdk-pixbuf/" efind-gdkpixbuf-0.2.1/efind-gdkpixbuf.spec -i
	fi
fi
