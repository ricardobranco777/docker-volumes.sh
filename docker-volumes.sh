#!/bin/bash
#
# The docker-export and docker-commit/docker-save commands do not save the container volumes.
# Use this script to save and load the container volumes.
#
# NOTES:
#  + This script could have been written in Python or Go, but the tarfile module and the tar package
#    lack support for writing sparse files.
#  + We use the Ubuntu docker image with tar v1.29+ that uses SEEK_DATA/SEEK_HOLE to manage sparse files.
#

VERSION="2.0.2"

# Set DOCKER=podman if you want to use podman instead of docker
DOCKER="${DOCKER:-docker}"

IMAGE="${IMAGE:-ubuntu:24.04}"

# We use .Destination since we're using --volumes-from
FILTER_BOTH='{{ range .Mounts }}{{ printf "%v\x00" .Destination }}{{ end }}'
FILTER_BIND='{{ range .Mounts }}{{ if eq .Type "bind" }}{{ printf "%v\x00" .Destination }}{{ end }}{{ end }}'
FILTER_VOLUME='{{ range .Mounts }}{{ if eq .Type "volume" }}{{ printf "%v\x00" .Destination }}{{ end }}{{ end }}'

FILTER="$FILTER_BOTH"

show_usage() {
	cat <<-EOF
		Usage: $0 [-b|--bind] [-V|--volume] [-v|--verbose] CONTAINER save|load TARBALL
		Options:
			-b, --bind	Use only bind-mounts
			-V, --volume	Use only internal volumes
			-v, --verbose	Be verbose
			--version	Print version and exit
			-h, --help	Show this help
	EOF
}

verbose=""
while [[ $# -gt 0 ]]; do
	case "$1" in
		-b|--bind)
			FILTER="$FILTER_BIND"
			shift ;;
		-V|--volume)
			FILTER="$FILTER_VOLUME"
			shift ;;
		-v|--verbose)
			verbose="-v"
			shift ;;
		-h|--help)
			show_usage
			exit 0 ;;
		--version)
			echo "$VERSION"
			exit 0 ;;
		-*)
			echo "Invalid option: $1" >&2
			show_usage >&2
			exit 1 ;;
		*)
			break ;;
	esac
done

if [[ $# -ne 3 || ! $2 =~ ^(save|load)$ ]] ; then
	echo "Usage: $0 [-v|--verbose] CONTAINER [save|load] TARBALL" >&2
	exit 1
fi

get_volumes () {
	$DOCKER inspect --type container -f "$FILTER" "$CONTAINER" | head -c -1 | sort -uz
}

save_volumes () {
	if [ -f "$TAR_FILE" ] ; then
		echo "ERROR: $TAR_FILE already exists" >&2
		exit 1
	fi
	umask 077
	# Create a void tar file to avoid mounting its directory as a volume
	touch -- "$TAR_FILE"
	tmp_dir=$(mktemp -du -p /)
	get_volumes | $DOCKER run --rm -i --volumes-from "$CONTAINER" -e LC_ALL=C.UTF-8 -v "$TAR_FILE:/${tmp_dir}/${TAR_FILE##*/}" "$IMAGE" tar -c -a $verbose --null -T- -f "/${tmp_dir}/${TAR_FILE##*/}"
}

load_volumes () {
	if [ ! -f "$TAR_FILE" ] ; then
		echo "ERROR: $TAR_FILE doesn't exist in the current directory" >&2
		exit 1
	fi
	tmp_dir=$(mktemp -du -p /)
	$DOCKER run --rm --volumes-from "$CONTAINER" -e LC_ALL=C.UTF-8 -v "$TAR_FILE:/${tmp_dir}/${TAR_FILE##*/}":ro "$IMAGE" tar -xp $verbose -S -f "/${tmp_dir}/${TAR_FILE##*/}" -C / --overwrite
}

CONTAINER="$1"
TAR_FILE=$(readlink -f "$3")

set -e

case "$2" in
	save)
		save_volumes ;;
	load)
		load_volumes ;;
esac
