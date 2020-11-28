#!/bin/bash

for d in "$@"; do
  if [ -d "$d" ] && [ -f "$d/config.bak" ]; then
    mv "$d/config{.bak,}"
  fi
done

