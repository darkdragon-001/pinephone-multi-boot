#!/bin/sh

gcc main.c -o extract `pkg-config --libs --cflags libarchive glib-2.0`
gcc main.c -DPARALLEL=1 -o extract1 `pkg-config --libs --cflags libarchive glib-2.0`
