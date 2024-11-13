![Build Status](https://github.com/ricardobranco777/docker-volumes.sh/actions/workflows/ci.yml/badge.svg)

# docker-volumes.sh
The [docker export](https://docs.docker.com/engine/reference/commandline/export/) and [docker commit](https://docs.docker.com/engine/reference/commandline/commit/) commands do not save the container volumes. Use this script to save and load the container volumes.

# Usage

```
Usage: docker-volumes.sh [-b|--bind] [-V|--volume] [-v|--verbose] CONTAINER save|load TARBALL
Options:
-b, --bind	Use only bind-mounts
-V, --volume	Use only internal volumes
-v, --verbose	Be verbose
-h, --help	Show this help
```

# Podman

To use [Podman](https://podman.io) instead of Docker, prepend `DOCKER=podman` to the command line to set the `DOCKER` environment variable.

# Example

Let's migrate a container to another host with all its volumes.

```
# Stop the container 
docker stop $CONTAINER
# Create a new image
docker commit $CONTAINER $CONTAINER
# Save and load image to another host
docker save $CONTAINER | ssh $USER@$HOST docker load 

# Save the volumes (use ".tar.gz" if you want compression)
docker-volumes.sh $CONTAINER save $CONTAINER-volumes.tar

# Copy volumes to another host
scp $CONTAINER-volumes.tar $USER@$HOST:

### On the other host:

# Create container with the same options used in the previous container
docker create --name $CONTAINER [<PREVIOUS CONTAINER OPTIONS>] $CONTAINER

# Load the volumes
docker-volumes.sh $CONTAINER load $CONTAINER-volumes.tar

# Start container
docker start $CONTAINER
```

To get the command used to create a container:
- podman: `podman container inspect -f '{{ range .Config.CreateCommand }}{{ printf "%s " . }}{{ end }}' $CONTAINER`
- docker lacks this functionality.

## Notes
- This script could have been written in Python or Go, but the tarfile module and the tar package lack support for writing sparse files.
- We use the Ubuntu Docker image with GNU tar v1.29+ that uses `SEEK_DATA` & `SEEK_HOLE` to [manage sparse files](https://www.gnu.org/software/tar/manual/html_chapter/tar_8.html#SEC137).
- To see the volumes that would be processed run `docker container inspect -f '{{json .Mounts}}' $CONTAINER` and pipe it to either [`jq`](https://stedolan.github.io/jq/) or `python -m json.tool`.

## BUGS / LIMITATIONS
- The `--volumes-from` option is [buggy in Podman < 4.7.0](https://github.com/containers/podman/issues/19529)
- Make sure the volumes are defined as such with the `VOLUME` directive. For example, the Apache image lacks them, but you can add them manually with `docker commit --change 'VOLUME /usr/local/apache2/htdocs' $CONTAINER $CONTAINER`
