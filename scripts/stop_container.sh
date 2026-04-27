#!/bin/bash
set -e

containerid=$(docker ps -q)

if [ ! -z "$containerid" ]; then
    docker rm -f $containerid
fi