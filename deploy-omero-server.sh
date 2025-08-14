#!/bin/bash
set -euo pipefail

# Container names
CONTAINER_DATABASE="database"
CONTAINER_OMEROSERVER="omeroserver"
CONTAINER_WORKER1="omeroworker-1"
CONTAINER_WORKER2="omeroworker-2"
CONTAINER_WORKER3="omeroworker-3"

OMERO_SERVER_UID=1000
OMERO_SERVER_GID=994

# CONFIG_omero_db_host=$CONTAINER_DATABASE
CONFIG_omero_db_host=10.10.52.18
CONFIG_omero_master_host=$CONTAINER_OMEROSERVER

# Images
POSTGRES_IMAGE="postgres:16"
OMERO_SERVER_IMAGE="openmicroscopy/omero-server:5"

# Volumes
DB_VOLUME="databasevolume"
OMERO_VOLUME="omerovolume"
OMERO_NETWORK="omeronetwork"

LOGS_DIR="./logs"
OMERO_DATA_DIR="/mnt/L-Drive/basic/divg/coreReits/OMERO/new"

# Remove old containers
for c in $CONTAINER_DATABASE $CONTAINER_OMEROSERVER $CONTAINER_WORKER1 $CONTAINER_WORKER2 $CONTAINER_WORKER3; do
  podman rm -f $c >/dev/null 2>&1 || true
done

# Remove old volumes
podman volume rm -f $DB_VOLUME >/dev/null 2>&1 || true
podman volume rm -f $OMERO_VOLUME >/dev/null 2>&1 || true

# Remove network
podman network rm $OMERO_NETWORK >/dev/null 2>&1 || true

# Remove logs directory
rm -rf $LOGS_DIR

# Remove and recreate OMERO data directory
rm -rf $OMERO_DATA_DIR
mkdir -p $OMERO_DATA_DIR

# Create volumes
podman volume create $DB_VOLUME
podman volume create $OMERO_VOLUME

# Create network
podman network create $OMERO_NETWORK

# Log directories
mkdir -p $LOGS_DIR

echo "Starting database..."
mkdir -p $LOGS_DIR/$CONTAINER_DATABASE
podman run -d --rm --name $CONTAINER_DATABASE \
  --network $OMERO_NETWORK \
  -e POSTGRES_USER=omero \
  -e POSTGRES_DB=omero \
  -e POSTGRES_PASSWORD=omero \
  -v $DB_VOLUME:/var/lib/postgresql/data:Z \
  -p 5432:5432 \
  $POSTGRES_IMAGE

echo "Starting OMERO server..."
mkdir -p $LOGS_DIR/$CONTAINER_OMEROSERVER
podman run -d --rm --name $CONTAINER_OMEROSERVER \
  --network $OMERO_NETWORK \
  -e CONFIG_omero_db_host=$CONFIG_omero_db_host \
  -e CONFIG_omero_db_user=omero \
  -e CONFIG_omero_db_pass=omero \
  -e CONFIG_omero_db_name=omero \
  -e CONFIG_omero_server_nodedescriptors="master:Blitz-0,Tables-0,Indexer-0,PixelData-0,DropBox,MonitorServer,FileServer,Storm omeroworker-1:Processor-0" \
  -e CONFIG_omero_master_host=$CONFIG_omero_master_host \
  -e ROOTPASS=omero \
  -v $OMERO_DATA_DIR:/OMERO \
  -v $LOGS_DIR/$CONTAINER_OMEROSERVER:/opt/omero/server/OMERO.server/var/log:z \
  -p 4063:4063 \
  -p 4064:4064 \
  -p 4061:4061 \
  --userns=keep-id:uid=${OMERO_SERVER_UID},gid=${OMERO_SERVER_GID} \
  $OMERO_SERVER_IMAGE

echo "Starting OMERO workers..."
podman build -t omero-worker ./worker

mkdir -p $LOGS_DIR/$CONTAINER_WORKER1
podman run -d --rm --name $CONTAINER_WORKER1 \
  --network $OMERO_NETWORK \
  -e CONFIG_omero_master_host=$CONFIG_omero_db_host \
  -e OMERO_WORKER_NAME=omeroworker-1 \
  -v $OMERO_DATA_DIR:/OMERO \
  -v $LOGS_DIR/$CONTAINER_WORKER1:/opt/omero/server/OMERO.server/var/log:z \
  --userns=keep-id:uid=${OMERO_SERVER_UID},gid=${OMERO_SERVER_GID} \
  omero-worker

echo "All OMERO containers started."
podman ps