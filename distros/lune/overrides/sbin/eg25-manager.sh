#!/bin/sh

function start()
{
	echo 1 > /sys/class/modem-power/modem-power/device/powered
}

function stop()
{
	echo 0 > /sys/class/modem-power/modem-power/device/powered
}

if [ "$1" = "start" ]; then
  echo "Starting EG25 modem..."
  start
elif [ "$1" = "stop" ]; then 
  echo "Stopping EG25 modem..."
  stop
fi


