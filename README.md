# docker-volumes.sh
The docker-export and docker-commit/docker-save commands do not save the container volumes. Use this script to save and load the container volumes.

# Notes
* This script could have been written in Python or Go, but the tarfile module and the tar package do not detect sparse files.
* We use the Ubuntu 18.04 Docker image with tar v1.29 that uses SEEK_DATA/SEEK_HOLE to detect sparse files.
* Volumes imported from other volumes via --volumes-from are ignored.
