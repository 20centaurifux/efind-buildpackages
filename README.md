# efind-buildpackages

This dialog-driven script can be used to create packages of
[efind](https://github.com/20centaurifux/efind) and related extensions. It's
tested with

    * Arch
    * CentOS
    * Debian
    * Fedora
    * OpenSUSE
    * Slackware
    * Ubuntu

Starting the script it lets you choose the tarballs you want to download
and create packages from. The locations are loaded from the SOURCES file.

Each file is downloaded and extracted. If an executable script with the
same name as the tarball (but ending with .sh instead of .tar.xz) is
found in the FIXES folder it's executed before the build process starts.

After building the package you can install it and run the test-suite shipped
with the tarball.

Scripts found in the AFTER directory can be started after the build and
install process.

I created this script for personal use. It doesn't test if your system
fulfils the requirements to build packages.
