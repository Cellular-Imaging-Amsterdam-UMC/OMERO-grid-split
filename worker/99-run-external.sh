#!/bin/bash
set -eu

omero=/opt/omero/server/venv3/bin/omero
cd /opt/omero/server

# Remote OMERO server configuration
MASTER_ADDR="${OMERO_MASTER_IP}"
WORKER_ADDR="${OMERO_WORKER_IP}"   # external IP that the master can reach
WORKER_BIND="0.0.0.0"              # bind inside container
WORKER_PORT="4061"

echo "Master addr: $MASTER_ADDR Worker bind: $WORKER_BIND:$WORKER_PORT publish: $WORKER_ADDR:$WORKER_PORT"

# Create worker config for remote connection
cat > OMERO.server/etc/$OMERO_WORKER_NAME.cfg << EOF
# OMERO worker configuration for remote connection
IceGrid.Node.Endpoints=tcp -h $WORKER_BIND -p $WORKER_PORT
IceGrid.Node.PublishedEndpoints=tcp -h $WORKER_ADDR -p $WORKER_PORT
IceGrid.Node.Name=$OMERO_WORKER_NAME
IceGrid.Node.Data=var/$OMERO_WORKER_NAME
IceGrid.Node.Output=var/log

Ice.StdOut=var/log/$OMERO_WORKER_NAME.out
Ice.StdErr=var/log/$OMERO_WORKER_NAME.err
EOF

# Create ice config for remote connection
cat > OMERO.server/etc/ice.config << EOF
Ice.Default.Router=OMERO.Glacier2/router:tcp -p 4063 -h $MASTER_ADDR
EOF

# Create internal config for remote connection  
cat > OMERO.server/etc/internal.cfg << EOF
Ice.Default.Locator=IceGrid/Locator:tcp -h $MASTER_ADDR -p 4061
IceGridAdmin.Username=root
IceGridAdmin.Password=ome

IceStormAdmin.TopicManager.Default=OMERO.IceStorm/TopicManager@OMERO.IceStorm.TopicManager
EOF

echo "Starting node $OMERO_WORKER_NAME (external connection)"
exec $omero node $OMERO_WORKER_NAME start --foreground