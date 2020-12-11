#!/bin/bash

set -e

# Zmienne Globalne
# ----------------
BRNAME="brlink"
BRMAX=512
CNTNAME="qoslink"
CNTMAX=256
IFNAME="eth"
IFMAX=32
          
# Sprawdza dostępność bridga 
# We - nazwa bridga
# --------------------------
checkbridge() {
  LISTBRIDGE=(`nmcli d | awk '{ print $1 }'`)
#  LISTBRIDGE=(`nmcli d | grep $BRNAME[[:digit:]] | awk '{ print $1 }'`)
  for (( CNT=0; CNT<${#LISTBRIDGE[@]}; CNT++ )) ; do
    if [[ "$1" = "${LISTBRIDGE[$CNT]}" ]] ; then
      return 0
    fi
  done
  return 1
}

# Zwraca numer pierwszego wolnego bridga
# Wy - nazwa bridga
# ------------------------------
freebridge() {
  LISTBRIDGE=(`nmcli d | grep $BRNAME[[:digit:]] | awk '{ print $1 }' | sort`)
  for (( CNT=0; CNT<$BRMAX; CNT++ )) ; do
    PASS=0
    for (( CNT2=0; CNT2<${#LISTBRIDGE[@]}; CNT2++ )) ; do
      if [[ "$BRNAME$CNT" = "${LISTBRIDGE[$CNT]}" ]] ; then
        PASS=1
      fi
    done
    if [[ $PASS = 0 ]] ; then 
      return $BRNAME$CNT
    fi
  done
}
 
# Zwraca numer pierwszego wolnego kontenera
# Wy - nazwa kontenera
# --------------------------------
freecontainer() {
  LISTCONTAINER=(`docker ps -a | awk '{ print $1 }' `)
  for (( CNT=0; CNT<$CNTMAX; CNT++ )) ; do
    PASS=0 
    for (( CNT2=1; CNT2<${#LISTCONTAINER[@]}; CNT2++ )) ; do
      CONTAINER=(`docker inspect --format='{{.Name}}' ${LISTCONTAINER[$CNT2]}`)
      CONTAINER=${CONTAINER:1:255}
      if [[ "$CNTNAME$CNT" = "$CONTAINER" ]] ; then 
        PASS=1
      fi
    done
    if [[ $PASS = 0 ]] ; then
      return $CNTNAME$CNT
    fi
  done
  die 5 "Brak wolnych kontenerów"
}
 
freecontainer host1
exit 0


# ---------------------------------------------------------------------------------------------
# ---------------------------------------------------------------------------------------------

#   | 0 | 1 | 2  | 3  | 4  | 5  | 6  | 7  | 8 | 9 | 10 | 11 | 12 | 13 | 14  | 15    |
WSK=(-h1 -h2 -if1 -if2 -ip1 -ip2 -br1 -br2 -s1 -s2 -l1  -l2  -d1  -d2  -link -update)

# Kopiowanie parametrów do tablicy PARAM[]. Możliwe więcej niż 9 danych wejściowych.
# ----------------------------------------------------------------------------------
CNT=0
CNTPARAM=$#
while [ $CNT -lt $CNTPARAM ]; do
  PARAM[$CNT]=$1
  shift 1
  let CNT=CNT+1 
done

# Uporządkowanie parametrów z tablicy PARAM[] do CFG[] według pozycji w WSK[].
# ----------------------------------------------------------------------------
for (( CNT=0; CNT<$CNTPARAM; CNT++ )) ; do
  for (( CNT2=0; CNT2<${#WSK[@]}; CNT2++ )) ; do 
    if [ ${PARAM[$CNT]} = ${WSK[$CNT2]} ] ; then
      CFG[$CNT2]=${PARAM[$CNT+1]}
      if [ ${PARAM[$CNT]} = "-update" ] ; then
        CFG[$CNT2]=1
      fi
    fi
  done
done
  
# Podgląd tablicy CFG[]
# ---------------------
#for (( CNT=0; CNT<${#WSK[@]}; CNT++ )) ; do
#  echo "CFG[$CNT] = ${CFG[$CNT]} " 
#done

# Komunikaty błędów
# -----------------
warn () {
  echo "$@" >&2
}
die () {
  status="$1"
  shift
  warn "$@"
  exit "$status"
}

# Weryfikacja parametrów i ich zależności.
# ----------------------------------------

# -----  Nazwy hostów są obowiązkowe  -------
if [[ -z ${CFG[0]} ]] || [[ -z ${CFG[1]} ]] ; then  
  die 1 "Brak nazwy hosta lub obu hostów - opcje -h1 lub -h2"
fi

# -----  Weryfikacja bridgy  ----------
if checkbridge "${CFG[6]}"; then
  die 3 "Nazwa bridge'a z opcji -h1 ${CFG[6]} jest już utworzona w systemie"
fi
if checkbridge "${CFG[7]}"; then
  die 4 "Nazwa Bridge'a z opcji -h2 ${CFG[7]} jest już utworzona w systemie"
fi




# Utworzenie kontenera łączącego hosty
# ------------------------------------
NAMECONTAINER=getnamecontainer    





exit 0

#tc qdisc del root dev eth1
#tc qdisc del root dev eth2
#tc qdisc add dev eth1 root handle 1:0 tbf rate 1Mbit latency 200ms burst 10k  
#tc qdisc add dev eth2 root handle 1:0 tbf rate 5Mbit latency 200ms burst 10k  
#tc qdisc add dev eth1 parent 1:1 handle 10:0 netem delay 1ms 1ms distribution normal loss 1% duplicate 1%
#tc qdisc add dev eth2 parent 1:1 handle 10:0 netem delay 1ms 1ms distribution normal loss 1% duplicate 1%

