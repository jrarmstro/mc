#!/usr/bin/env bash

echo "Adding $1 to whitelist"
docker exec -it mc-mc-1 rcon-cli whitelist add $1

