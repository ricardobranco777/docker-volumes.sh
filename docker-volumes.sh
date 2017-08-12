#!/bin/bash
#
# The docker-export and docker-commit/docker-save commands do not save the container volumes.
# Use this script to save and load the container volumes.
#
# v1.3 by Ricardo Branco
#
# NOTES:
#  + This script could have been written in Python or Go, but the tarfile module and the tar
#    package do not detect sparse files.
#  + We use the Ubuntu 17.04 Docker image with tar v1.29 that uses SEEK_DATA/SEEK_HOLE to
#    detect sparse files.
#  + Volumes imported from other volumes via --volumes-from are ignored.
#

if [[ $1 == "-v" ]] ; then
	v="-v"
	shift
fi

if [[ $# -ne 3 || ! $2 =~ ^(save|load)$ ]] ; then
	echo "Usage: $0 [-v] CONTAINER [save|load] TARBALL" >&2
	exit 1
fi

IMAGE="ubuntu:17.04"

get_volumes () {
	cat <(docker inspect --type container -f '{{range $v, $_ := .Config.Volumes}}{{printf "%v\x00" $v}}{{end}}' $CONTAINER | head -c -1) \
	    <(docker inspect --type container -f '{{range $_, $v := .HostConfig.Binds}}{{printf "%v\x00" $v}}{{end}}' $CONTAINER | head -c -1) \
	cut -z -d: -f2 | sort -uz
}

save_volumes () {
	if [ -f "$TAR_FILE" ] ; then
		echo "ERROR: $TAR_FILE already exists in the current directory" >&2
		exit 1
	fi
	umask 077
	# We create a void tar file to avoid mounting the directory as a volume
	touch "$TAR_FILE"
	get_volumes | docker run --rm -i --volumes-from $CONTAINER -e LC_ALL=C.UTF-8 -v "$TAR_FILE:/backup/${TAR_FILE##*/}" $IMAGE tar -c -a $v --null -T- -f "/backup/${TAR_FILE##*/}"
}

load_volumes () {
	if [ ! -f "$TAR_FILE" ] ; then
		echo "ERROR: $TAR_FILE doesn't exist in the current directory" >&2
		exit 1
	fi
	docker run --rm --volumes-from $CONTAINER -e LC_ALL=C.UTF-8 -v "$TAR_FILE:/backup/${TAR_FILE##*/}":ro $IMAGE tar -xp $v -S -f "/backup/${TAR_FILE##*/}" -C / --overwrite
}

CONTAINER="$1"
TAR_FILE="$3"

set -e

case "$2" in
	save)
		save_volumes ;;
	load)
		load_volumes ;;
esac
