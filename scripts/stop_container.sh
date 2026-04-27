#!/bin/bash
set -e

# Stop the running container (if any)
containerid=$(docker ps -q)
docker rm -f $containerid
