#!/bin/bash
set -e

#  set +x

# Zmienne Globalne
# ----------------
BRPREFIX="brlink"	# Domyślne nazwy bridgy, kontenerów oraz interfejsów
BRMAX=512		# tworzonych w tych kontenerach.
CNTPREFIX="qoslink"
CNTMAX=256
IFPREFIX="eth"
IFMAX=32
NETDEFAULT="10.1.1.0/24" # Domyślny adres sieci. Obsluga 254 sieci.

          
# Sprawdza dostępność bridga 
# We - $1 nazwa bridga
# --------------------------
checkbridge() {
  LISTBRIDGE=(`nmcli d | awk '{ print $1 }'`)
#  LISTBRIDGE=(`nmcli d | grep $BRPREFIX[[:digit:]] | awk '{ print $1 }'`)
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
  LISTBRIDGE=(`nmcli d | grep $BRPREFIX[[:digit:]] | awk '{ print $1 }' | sort`)
  for (( CNT=0; CNT<$BRMAX; CNT++ )) ; do
    PASS=0
    if [[ "$BRPREFIX$CNT" = "${CFG[6]}" || "$BRPREFIX$CNT" = "${CFG[7]}" ]] ; then
      PASS=1
    fi
    ANS=(`echo ${LISTBRIDGE[@]} | grep $BRPREFIX$CNT `)
    if [[ -n ${ANS[@]} ]] ; then 
      PASS=1
    fi
    if [[ $PASS -eq 0 ]] ; then 
      BRNAME=$BRPREFIX$CNT		# Wyszukana wolna nazwa dla nowego bridga
      return 0
    fi
  done
  die 6 "Brak wolnych bridg'y"
}

# Sprawdza dostępność kontenera
# We - $1 nazwa kontenera
# --------------------------
checkcontainer() {
  LISTCONTAINER=(`docker ps -a | sed -n -e '1!p' | awk '{ print $(NF) }' `)
  for (( CNT=0; CNT<${#LISTCONTAINER[@]}; CNT++ )) ; do
    if [[ "$1" = "${LISTCONTAINER[$CNT]}" ]] ; then
      return 0
    fi
  done
  return 1
}
 
# Zwraca numer pierwszego wolnego kontenera
# Wy - nazwa kontenera
# --------------------------------
freecontainer() {
  LISTCONTAINER=(`docker ps -a | sed -n -e '1!p' | awk '{ print $(NF) }' `)
  for (( CNT=0; CNT<$CNTMAX; CNT++ )) ; do
    PASS=0 
    ANS=(`echo ${LISTCONTAINER[@]} | grep $CNTPREFIX$CNT `)
    if [[ -n ${ANS[@]} ]] ; then
      PASS=1
    fi
    if [[ $PASS -eq 0 ]] ; then
      CNTNAME=$CNTPREFIX$CNT 		# Wyszukana wolna nazwa dla nowego kontenera
      return 0
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

 
# Sprawdza poprawnosc parametrow sieci
# We - $1 IP/Netmask
# ------------------------------------
parseip() {
#  ANS1=(`echo $1 | grep -E "^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\/([2-9]|[12][0-9])"`)
  ANS1=(`echo $1 | grep -E "^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\/"`)
  M=(`echo $1 | awk -F/ '{print $2}' `)
  IP=(`echo $1 | awk -F/ '{print $1}' | awk -F. '{print $1,$2,$3,$4}' `)
  if [[ -n $ANS1 ]] && [[ "$M" -gt  "1" ]] && [[ "$M" -lt "30" ]] ; then
    return 0		# IP/mask poprawne
  else
    return 1		# IP/mask błędne
  fi
}


# We - $1 IP/Netmask  format:  x.y.z.v/mm 
# We - $2 IP/Netmask
# We - $3 1 Widoczność komunikatów,    0 - brak
# ----------------------------
comparenet() {
#echo ========  $1  ==  $2    ========
  M1=(`echo $1 | awk -F/ '{print $2}' `)
  M2=(`echo $2 | awk -F/ '{print $2}' `)
  IP1=(`echo $1 | awk -F/ '{print $1}' | awk -F. '{print $1,$2,$3,$4}' `)
  IP2=(`echo $2 | awk -F/ '{print $1}' | awk -F. '{print $1,$2,$3,$4}' `)
  MASK1=(` ipcalc $1 -m | awk -F= '{print $2}' | awk -F. '{print $1,$2,$3,$4}' `)
  MASK2=(` ipcalc $2 -m | awk -F= '{print $2}' | awk -F. '{print $1,$2,$3,$4}' `)
  NET1=(` ipcalc $1 -n | awk -F= '{print $2}' | awk -F. '{print $1,$2,$3,$4}' `)
  NET1=(` ipcalc $1 -n | awk -F= '{print $2}' | awk -F. '{print $1,$2,$3,$4}' `)
  BROADCAST1=(` ipcalc $1 -b | awk -F= '{print $2}' | awk -F. '{print $1,$2,$3,$4}' `)
  BROADCAST2=(` ipcalc $1 -b | awk -F= '{print $2}' | awk -F. '{print $1,$2,$3,$4}' `)

  if [[ "$M1" -eq "$M2" ]] ; then
    if [[ "$[ ${IP1[0]} & ${MASK1[0]} ]" -eq "$[ ${IP2[0]} & ${MASK2[0]} ]" ]] && [[ "$[ ${IP1[1]} & ${MASK1[1]} ]" -eq "$[ ${IP2[1]} & ${MASK2[1]} ]" ]] && [[ "$[ ${IP1[2]} & ${MASK1[2]} ]" -eq "$[ ${IP2[2]} & ${MASK2[2]} ]" ]] && [[ "$[ ${IP1[3]} & ${MASK1[3]} ]" -eq "$[ ${IP2[3]} & ${MASK2[3]} ]" ]] ; then 
      if [[ "${IP1[0]}" -eq "${IP2[0]}" ]] && [[ "${IP1[1]}" -eq "${IP2[1]}" ]] && [[ "${IP1[2]}" -eq "${IP2[2]}" ]] && [[ "${IP1[3]}" -eq "${IP2[3]}" ]] ; then		
        NET=0		# Konflikt adresów IP
        if [[ "$3" -eq "1" ]] ; then 
          msg 16 "Konflikt adresów IP:  $1"
        fi
        return 
      else
        NET=3		# Podsieci zgodne, IP bez konfliktu
        if [[ "$3" -eq "1" ]] ; then 
          msg "Adresy sieci zgodne -ip1:$1  -ip2:$2, IP bez konfliktu"
        fi
        return
      fi
    else
      NET=2  		# Różne podsieci 
      if [[ "$3" -eq "1" ]] ; then 
        msg "Adresy sieci $1 $2 niezgodne"
      fi
      return
    fi
  else
    NET=1			# Różne długości maski
    if [[ "$3" -eq "1" ]] ; then 
      msg "Różne długości adresu sieci (maski) $1 $2"
    fi
    return
  fi
  die 20 "Bład w funkcji comparenet()"
}


# Sprawdza dostępnosc parametrów sieci
# We - $1 IP/Netmask
# We - $2 nazwa kontenera
# ------------------------------------
checkip() {
  if parseip "$1" ; then
    LISTIP=(`docker exec $2 ip a | awk '/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\// {print $2,$(NF)}' `)
 #   echo ${LISTIP[@]}
 #   echo ${#LISTIP[@]}
    let LISTIPMAX=${#LISTIP[@]}
  #  echo $LISTIPMAX
    STAT=1				# Domyslnie IP jest poza adresacja sieci w testowanym kontenerze
    for (( CNT=0; CNT<$LISTIPMAX; CNT=$CNT+2 )) ; do

      if [[ "$1" = "${LISTIP[$CNT]}" ]] ; then
        die 15 "Konflikt adresów IP $1 w kontenerze $2"
        return 		# Podane IP jest w konflikcie z IP w danym kontenerze
      fi
#      echo ----- $CNT:  $1   ----  ${LISTIP[$CNT]}    ------
      comparenet "$1" "${LISTIP[$CNT]}"
#   echo eurpqurouroqurpoqueroqurouweo
#    echo ++++ $NET:    $STAT
      case "$NET" in
        "3")
#          echo "check case - podsieci zgodne IP bez konfliktu"
          if [[ "$STAT" -lt "4" ]] ; then 
            STAT=3
          fi ;;
        "2")
#          echo "check case - podsieci rózne"
          if [[ "$STAT" -lt "3" ]] ; then
            STAT=2
          fi ;;
        "1")
#          echo "check case - rozne dlugosci maski"
          if [[ "$STAT" -lt "2" ]] ; then
            STAT=1
          fi ;;
        "0")
#          echo "check case - konflikt adresow"
	  die 15 "Konflikt adresów IP $1 w kontenerze $2"
          ;;
      esac
    done
#      echo " STAT = $STAT"
      return
  elseif
    die 12 "Niepoprawne dane lub format adresu sieci w funkcji <checkip>."
  fi
}

# Zwraca wolny adres IP dla danej sieci 
# We - $1 Adres IP/Mask do którego ma być wyszukany
#         nowy wolny adres w danej sieci
freeip() {
  comparenet $1 "0.0.0.0"
#  echo ${M1[@]}
#  echo ${IP1[@]}
#  echo ${MASK1[@]}
#  echo ${NET1[@]}
#  echo ${BROADCAST1[@]}
#  echo ${NET1[3]}
  
  NEGM[3]=$[256-${MASK1[3]}]			
  NEGM[2]=$[256-${MASK1[2]}]
  NEGM[1]=$[256-${MASK1[1]}]
  NEGM[0]=$[256-${MASK1[0]}]
  CNTIP=$[NEGM[3]*NEGM[2]*NEGM[1]*NEGM[0]-2]		# obliczanie całkowitej ilości adresów IP w danej sieci

  IM3=${NET1[3]}; IM2=${NET1[2]}; IM1=${NET1[1]}; IM0=${NET1[0]}
 
  LISTCONTAINER=(`docker ps | sed -n -e '1!p' | awk '{ print $(NF) }' `)
  for (( CNT2=0; CNT2<${#LISTCONTAINER[@]}; CNT2++ )) ; do
    echo =
    echo =============  kontener  ${LISTCONTAINER[$CNT2]}  ===================
    LISTIP=(`docker exec ${LISTCONTAINER[$CNT2]} ip a | awk '/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\// {print $2,$(NF)}' `)
    let LISTIPMAX=${#LISTIP[@]}
    for (( CNT=0; CNT<$LISTIPMAX; CNT=$CNT+2 )) ; do
      echo =
      echo =============  IP   ${LISTIP[$CNT]}  ===================
      echo =============  IP   ${LISTIP[@]}  ===================
      for (( I0=${NET1[0]}; I0<=${BROADCAST1[0]}; I0++ )) ; do
    #    if [[ "$NET" -eq "3" ]] ; then
          I0=$IM0
    #    fi
        for (( I1=${NET1[1]}; I1<=${BROADCAST1[1]}; I1++ )) ; do
    #      if [[ "$NET" -eq "3" ]] ; then
            I1=$IM1
    #      fi 
          for (( I2=${NET1[2]}; I2<=${BROADCAST1[2]}; I2++ )) ; do
    #        if [[ "$NET" -eq "3" ]] ; then
              I2=$IM2
    #        fi
            for (( I3=$[NET1[3]+1]; I3<=$[BROADCAST1[3]-1]; I3++ )) ; do
    #          if [[ "$NET" -eq "3" ]] ; then
                I2=$IM2
    #          fi
              echo "Memory" "$IM0.$IM1.$IM2.$IM3"
              comparenet "$I0.$I1.$I2.$I3/$M1" ${LISTIP[$CNT]} "1"
               if [[ "$NET" -eq "1" ]] ; then		
                 echo "1a:  $NET" "$I0.$I1.$I2.$I3/$M1" ${LISTIP[$CNT]}
                 I3=${BROADCAST1[3]}; I2=${BROADCAST1[2]}; I1=${BROADCAST1[1]}; I0=${BROADCAST1[0]};
                 echo "1b:  $NET" "$I0.$I1.$I2.$I3/$M1" ${LISTIP[$CNT]}
                # CNT=$[CNT+2]; I3=$[I3-1]
                 if [[ "$CNT" -gt "$LISTIPMAX" ]] ; then
                   CNT2=$[CNT2+1]; CNT=0
                   break
                 fi
               fi              
               if [[ "$NET" -eq "3" ]] ; then
                 echo "3a$NET" "$I0.$I1.$I2.$I3/$M1" ${LISTIP[$CNT]}
                 IM3=$I3; IM2=$I2; IM1=$I1; IM0=$I0
                 I3=${BROADCAST1[3]}; I2=${BROADCAST1[2]}; I1=${BROADCAST1[1]}; I0=${BROADCAST1[0]};
#                 CNT2=$[CNT2+1]; CNT=0
                 echo "3b$NET" "$I0.$I1.$I2.$I3/$M1" ${LISTIP[$CNT]}
               fi
               if [[ "$NET" -eq "2" ]] ; then
                 echo "2a$NET" "$I0.$I1.$I2.$I3/$M1" ${LISTIP[$CNT]}
                 I3=${BROADCAST1[3]}; I2=${BROADCAST1[2]}; I1=${BROADCAST1[1]}; I0=${BROADCAST1[0]};
#                 CNT2=$[CNT2+1]; CNT=0
                 echo "2b$NET" "$I0.$I1.$I2.$I3/$M1" ${LISTIP[$CNT]}
               fi
            done
          done
        done
      done
    done
  done
  return
}


# ---- Przypisanie nazwy dla kontenera <c>
set_c() {
if [[ -z ${CFG[0]} ]] ; then
  if freecontainer ; then 
    CFG[0]=$CNTNAME
    msg "Przypisano nazwę kontenera -c: <${CFG[0]}>"
  fi
fi
return 0
}

# -----  Przypisanie nazwy dla bridga <br1>  -------
set_br1() {
if [[ -z ${CFG[7]} ]] ; then
  if freebridge ; then 
    CFG[7]=$BRNAME
    msg "Przypisano nazwę bridga -br1: <${CFG[7]}>"
  fi
fi
return 0
}

# -----  Przypisanie nazwy dla bridga <br2>  -------
set_br2() {
if [[ -z ${CFG[8]} ]] ; then
  if freebridge ; then 
    CFG[8]=$BRNAME
    msg "Przypisano nazwę bridga -br2: <${CFG[8]}>"
  fi
fi
return 0
}

# -----  Przypisanie nazwy dla interfejsu <if1> w hoscie <-h1>  -------
set_if1() {
if [[ -z ${CFG[3]} ]] ; then
  if freeinterface "${CFG[1]}" ; then
    CFG[3]=$IFNAME
    msg "Przypisano nazwę interfejsu -if1: <${CFG[3]}> w kontenerze <${CFG[1]}>"
  fi
fi
return 0
}

# -----  Przypisanie nazwy dla interfejsu <if2> w hoscie  <-h2>  -------
set_if2() {
if [[ -z ${CFG[4]} ]] ; then
  if freeinterface "${CFG[2]}" ; then
    CFG[4]=$IFNAME
    msg "Przypisano nazwę interfejsu -if2: <${CFG[4]}> w kontenerze <${CFG[2]}>"
  fi
fi
return 0
}

# Komunikaty błędów
# -----------------
msg () {				# Komunikaty wyswietlane przy ustawionej opcji  -v
  if [[ ${CFG[17]} ]] ; then
    echo $1$2$3
  fi
}


err () {
#  if [[ ${CFG[17]} ]] ; then
    echo "$@" >&2
#  fi
}
die () {
  status="$1"
  shift
  err "$@"
  exit "$status"
}


# Weryfikacja wprowadzonych parametrów i ich zależności
# -----------------------------------------------------
# ---------------------------------------------------------------------------------------------
#     QoSLink - skrypt symulujący sieć składającą się z łączy, switchy oraz routerów 
#               wraz ustalaniem parametrów QoS poszczególnych łączy.
# ---------------------------------------------------------------------------------------------
#
#   Tablica z dostępnymi opcjami oraz parametrami wejściowymi dla skyptu
#   | 0 | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9    | 10   | 11   | 12   | 13    | 14    | 15  | 16    | 17 | 18 | 19 | 20 | 21 |
WSK=(-c  -h1  -h2  -if1 -if2 -ip1 -ip2 -br1 -br2 -band1 -band2 -loss1 -loss2 -delay1 -delay2 -link -update -v   -sw1 -sw2 -r1  -r2 )
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

# set -x 

# Weryfikacja wprowadzonych parametrów i ich zależności
# -----------------------------------------------------

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

# ------  Określenie rodzaju polaczenia (Host-Host, Host-Switch, Host-Router, Switch-Router, itp)
# -----------------------------------------------------------------------------------------------

KOD=0
if [[ -n ${CFG[1]} ]] ; then
  let KOD=$KOD+128 ; fi
if [[ -n ${CFG[2]} ]] ; then 
  let KOD=$KOD+64  ; fi
if [[ -n ${CFG[5]} ]] ; then
  let KOD=$KOD+32  ; fi
if [[ -n ${CFG[6]} ]] ; then
  let KOD=$KOD+16  ; fi
if [[ -n ${CFG[18]} ]] ; then
  let KOD=$KOD+8   ; fi
if [[ -n ${CFG[19]} ]] ; then
  let KOD=$KOD+4   ; fi
if [[ -n ${CFG[20]} ]] ; then
  let KOD=$KOD+2   ; fi
if [[ -n ${CFG[21]} ]] ; then
  let KOD=$KOD+1   ; fi
#echo ---- $KOD ----

case "$KOD" in

240)						# h1 + ip1  ---  h2 + ip2  
    comparenet "${CFG[5]}" "${CFG[6]}" "1"
    if [[ "$NET" -eq "3" ]] ; then
      checkip ${CFG[5]} ${CFG[1]}
      checkip ${CFG[6]} ${CFG[1]}
      checkip ${CFG[5]} ${CFG[2]}
      checkip ${CFG[6]} ${CFG[2]}
      freeip ${CFG[5]}
#      freeip ${CFG[6]}
    else
      exit 0
    fi
    ;;

*)
    echo "Nieprawidłowe zestawienie parametrów."
    exit 0 ;;  
esac



















echo Koniec

exit 0


#if checkip "${CFG[5]}" "${CFG[1]}"; then
#  die 8 "Adres IP/Netmask z opcji -ip1 jest w konflikcie z pozostałymi adresami w kontenerze <${CFG[1]}>"
#fi
#
#if checkip "${CFG[6]}" "${CFG[2]}"; then
#  die 8 "Adres IP/Netmask z opcji -ip2 jest w konflikcie z pozostałymi adresami w kontenerze <${CFG[1]}>"
#fi
#


# Ustalanie brakujących parametrów
# --------------------------------

# ---- Przypidsanie nazwy dla kontenera <c>
if [[ -z ${CFG[0]} ]] ; then
  if freecontainer ; then 
    CFG[0]=$CNTNAME
    msg "Przypisano nazwę kontenera -c: <${CFG[0]}>"
  fi
fi

# -----  Przypisanie nazwy dla bridga <br1>  -------
if [[ -z ${CFG[7]} ]] ; then
  if freebridge ; then 
    CFG[7]=$BRNAME
    msg "Przypisano nazwę bridga -br1: <${CFG[7]}>"
  fi
fi

# -----  Przypisanie nazwy dla bridga <br2>  -------
if [[ -z ${CFG[8]} ]] ; then
  if freebridge ; then 
    CFG[8]=$BRNAME
    msg "Przypisano nazwę bridga -br2: <${CFG[8]}>"
  fi
fi

# -----  Przypisanie nazwy dla interfejsu <if1> w hoscie <-h1>  -------
if [[ -z ${CFG[3]} ]] ; then
  if freeinterface "${CFG[1]}" ; then
    CFG[3]=$IFNAME
    msg "Przypisano nazwę interfejsu -if1: <${CFG[3]}> w kontenerze <${CFG[1]}>"
  fi
fi

# -----  Przypisanie nazwy dla interfejsu <if2> w hoscie  <-h2>  -------
if [[ -z ${CFG[4]} ]] ; then
  if freeinterface "${CFG[2]}" ; then
    CFG[4]=$IFNAME
    msg "Przypisano nazwę interfejsu -if2: <${CFG[4]}> w kontenerze <${CFG[2]}>"
  fi
fi

########################################!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!    usunąć !!!!!!!!!!!!!!!!!!!!!!!
# Podgląd tablicy CFG[]
# ---------------------
#for (( CNT=0; CNT<${#WSK[@]}; CNT++ )) ; do
#  echo "CFG[$CNT] -eq ${CFG[$CNT]} " 
#done


# Uruchomienie kontenera łączącego hosty
# --------------------------------------
docker run -d -ti --name ${CFG[0]} --hostname ${CFG[0]} --cap-add NET_ADMIN host:v1 /bin/bash
msg "Uruchomienie kontenera ${CFG[0]}"

# Konfiguraacja poloczen kontenerow
# ---------------------------------
# bridge - host1
pipework ${CFG[7]} -i ${CFG[3]} ${CFG[1]} ${CFG[5]}
msg "Polaczenie bridg'a -br1 <${CFG[7]}> z hostem <${CFG[1]}>"

# bridge - host2
pipework ${CFG[8]} -i ${CFG[4]} ${CFG[2]} ${CFG[6]}
msg "Polaczenie bridg'a -br2 <${CFG[8]}> z hostem <${CFG[2]}>"



exit 0

#tc qdisc del root dev eth1
#tc qdisc del root dev eth2
#tc qdisc add dev eth1 root handle 1:0 tbf rate 1Mbit latency 200ms burst 10k  
#tc qdisc add dev eth2 root handle 1:0 tbf rate 5Mbit latency 200ms burst 10k  
#tc qdisc add dev eth1 parent 1:1 handle 10:0 netem delay 1ms 1ms distribution normal loss 1% duplicate 1%
#tc qdisc add dev eth2 parent 1:1 handle 10:0 netem delay 1ms 1ms distribution normal loss 1% duplicate 1%

