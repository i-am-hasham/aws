#!/bin/bash
set -e

containerid=$(docker ps -q)

if [ -z "$containerid" ]; then
    echo "No container to stop"
else
    docker rm -f $containerid
fi