#!/bin/bash

# -------------------------- funkcje -----

function stop()
{

  docker stop host1
  docker stop host2
  docker rm host1
  docker rm host2

  echo -e "Completed."
  exit 0
}


function start()
{
  docker run -d -ti --name host1 --hostname host1 --cap-add NET_ADMIN host:v1 /bin/bash
  docker run -d -ti --name host2 --hostname host2 --cap-add NET_ADMIN host:v1 /bin/bash
  
  pipework br1 -i eth1 host1 10.1.0.1/24
  pipework br2 -i eth1 host2 10.1.0.4/24

  echo -e "Complete.\n"
}

# --------------------------- Main -----

argc=$#

if [ $argc = 0 ]
  then
  echo -e "Brak parametrĂłw\n"
  exit 1
fi

if [ $1 = "start" ]
  then
  start
  exit 0
fi

if [ $1 = "stop" ]
  then
  stop
  exit 0
fi

echo -e "Niepoprawny parametr\nUzuj: start stop restart"
exit 1

