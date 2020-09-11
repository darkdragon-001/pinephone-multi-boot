#!/bin/sh

gcc main.c -o extract `pkg-config --libs --cflags libarchive glib-2.0`