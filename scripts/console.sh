#!/usr/bin/env bash

if [[ -n "$1" ]]; then
  docker exec mc-mc-1 rcon-cli "$1"
else
  docker exec -it mc-mc-1 rcon-cli
fi

