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
 
 
# Sprawdza dostępność interfejsów w kontenerze
# We - $1 nazwa interfejsu w kontenerze $2
# We - $2 nazwa kontenera
# --------------------------
checkinterface() {
  LISTINTERFACE=(`docker exec $2 ip a | awk -F': ' '{print $2}' | awk -F@ '/./ {print $1}' `)
  for (( CNT=0; CNT<${#LISTINTERFACE[@]}; CNT++ )) ; do
    if [[ "$1" = "${LISTINTERFACE[$CNT]}" ]] ; then
      return 0
    fi
  done
  return 1
}
 
# Zwraca numer pierwszego wolnego interfejsu w kontenerze
# We - $1 nazwa kontenera
# Wy - nazwa interfejsu w kontenerze $1
# --------------------------------
freeinterface() {
  LISTINTERFACE=(`docker exec $1 ip a | awk -F': ' '{print $2}' | awk -F@ '/./ {print $1}' `)
  for (( CNT=0; CNT<$CNTMAX; CNT++ )) ; do
    PASS=0 
    for (( CNT2=0; CNT2<${#LISTINTERFACE[@]}; CNT2++ )) ; do
      if [[ "$IFPREFIX$CNT" = "${LISTINTERFACE[$CNT2]}" ]] ; then 
        PASS=1
      fi
    done
    if [[ $PASS -eq 0 ]] ; then
      IFNAME=$IFPREFIX$CNT 		# Wyszukana wolna nazwa dla nowego interfejsu
      return 0
    fi
  done
  die 5 "Brak wolnych interfejsow"
}

 


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
      if [ ${PARAM[$CNT]} = "-update" ] ; then		# Zapis dotyczącej aktualizacji danych 
        CFG[$CNT2]=0
      fi
      if [ ${PARAM[$CNT]} = "-v" ] ; then		# Zapis dotyczacy wyswietlen komunikatow
        CFG[$CNT2]=0
      fi
      if [ ${PARAM[$CNT]} = "-L" ] ; then		# Zapis dotyczacy wyswietlen komunikatow
        CFG[$CNT2]=0
      fi
      if [ ${PARAM[$CNT]} = "-S" ] ; then		# Zapis dotyczacy wyswietlen komunikatow
        CFG[$CNT2]=0
      fi
      if [ ${PARAM[$CNT]} = "-R" ] ; then		# Zapis dotyczacy wyswietlen komunikatow
        CFG[$CNT2]=0
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

# -----  Weryfikacja nazwy kontenera  -------
if [[ -n ${CFG[0]} ]] ; then
  if checkcontainer "${CFG[0]}" ; then
    die 3 "Nazwa kontenera z opcji -c ${CFG[0]} jest już utworzona w systemie"
  fi
fi

# -----  Weryfikacja bridgy  ----------
if [[ -n ${CFG[7]} ]] ; then
  if checkbridge "${CFG[7]}" ; then
    die 4 "Nazwa bridge'a z opcji -br1 ${CFG[7]} jest już utworzona w systemie"
  fi
fi

if [[ -n ${CFG[8]} ]] ; then
  if checkbridge "${CFG[8]}" ; then
    die 5 "Nazwa Bridge'a z opcji -br2 ${CFG[8]} jest już utworzona w systemie"
  fi
fi

# -----  Weryfikacja interfejsow  -----
if [[ -n ${CFG[3]} ]] ; then
  if checkinterface "${CFG[3]}" "${CFG[1]}" ; then
    die 5 "Nazwa interfejsu z opcji -if1 ${CFG[3]} jest już utworzona w kontenerze ${CFG[1]}"
  fi
fi

if [[ -n ${CFG[4]} ]] ; then
  if checkinterface "${CFG[4]}" "${CFG[2]}" ; then
    die 5 "Nazwa interfejsu z opcji -if2 ${CFG[4]} jest już utworzona w kontenerze ${CFG[2]}"
  fi
fi

# ----  Weryfikacja poprawności IP1
if [[ -n ${CFG[5]} ]] ; then
  if parseip ${CFG[5]}  ; then
    : # :
  else
    die 8 "Niepoprawny format parametrow sieci dla -ip1. (format: x.y.z.v/mask) mask:<1,29>"
  fi
fi

# ----  Weryfikacja poprawności IP2
if [[ -n ${CFG[6]} ]] ; then
  if parseip ${CFG[6]}  ; then
    : # :
  else
    die 8 "Niepoprawny format parametrow sieci dla -ip2. (format: x.y.z.v/mask) mask:<1,29>"
  fi
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

