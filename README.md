# docker-volumes.sh
The [docker export](https://docs.docker.com/engine/reference/commandline/export/) and [docker commit](https://docs.docker.com/engine/reference/commandline/commit/) commands do not save the container volumes. Use this script to save and load the container volumes.

# Usage

`docker-volumes.sh [-v|--verbose] CONTAINER [save|load] TARBALL`

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

# Copy image and volumes to another host
scp $CONTAINER.tar $CONTAINER-volumes.tar $USER@$HOST:

### On the other host:

# Create container with the same options used by the previous container
docker create --name $CONTAINER [<PREVIOUS CONTAINER OPTIONS>] $CONTAINER

# Load the volumes
docker-volumes.sh $CONTAINER load $CONTAINER-volumes.tar

# Start container
docker start $CONTAINER
```

# Notes
* This script could have been written in Python or Go, but the tarfile module and the tar package lack support for writing sparse files.
* We use the Ubuntu 18.04 Docker image with tar v1.29 that uses SEEK_DATA/SEEK_HOLE to manage sparse files.
* Volumes imported from other volumes via `--volumes-from` are ignored.
