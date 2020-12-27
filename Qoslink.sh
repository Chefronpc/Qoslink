#!/bin/bash
set -e

#  set +x

# Parametry wstępne -  Globalne
# ----------------
BRPREFIX="brlink"	# Domyślne nazwy bridgy, linków oraz interfejsów
BRMAX=512		# tworzonych w tych kontenerach.
QOSPREFIX="qoslink"
QOSMAX=256
QUAGGAPREFIX="quaggalink"
QUAGGAMAX=256
IFPREFIX="eth"
IFMAX=64
DEFAULTNET="10.10.10.0/26" # Domyślny adres sieci. Obsluga 254 sieci.


# Komentarze i błędy
# ------------------------------
msg () {                        # Komentarze wyswietlane przy ustawionej opcji  -v
  if [[ ${CFG[21]} ]] ; then
    echo $1$2$3$4$5$6$7$8$9
  fi
}

msg2 () {                       # Komunikaty debugowania wyswietlane przy ustawionej opcji  -V
  if [[ ${CFG[22]} ]] ; then
    echo $1$2$3$4$5$6$7$8$9
  fi
}

err () {
#  if [[ ${CFG[22]} ]] ; then   # Ustawić prawidlowy numer $CFG[xx]
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
  for (( CNT=0; CNT<$QOSMAX; CNT++ )) ; do
    PASS=0 
    ANS=(`echo ${LISTCONTAINER[@]} | grep $QOSPREFIX$CNT `)
    if [[ -n ${ANS[@]} ]] ; then
      PASS=1
    fi
    if [[ $PASS -eq 0 ]] ; then
      QOSNAME=$QOSPREFIX$CNT 		# Wyszukana wolna nazwa dla nowego linka (kontenera)
      return 0
    fi
  done
  die 5 "Brak wolnych kontenerów"
}
 
# Sprawdza dostępność routera Quagga
# We - $1 nazwa kontenera
# --------------------------
checkrouter() {
  LISTROUTER=(`docker ps -a | sed -n -e '1!p' | awk '{ print $(NF) }' `)
  for (( CNT=0; CNT<${#LISTROUTER[@]}; CNT++ )) ; do
    if [[ "$1" = "${LISTROUTER[$CNT]}" ]] ; then
      return 0
    fi
  done
  return 1
}
 
# Zwraca numer pierwszego wolnego routera
# Wy - nazwa kontenera
# --------------------------------
freerouter() {
  LISTROUTER=(`docker ps -a | sed -n -e '1!p' | awk '{ print $(NF) }' `)
  for (( CNT=0; CNT<$QUAGGAMAX; CNT++ )) ; do
    PASS=0 
    ANS=(`echo ${LISTROUTER[@]} | grep $QUAGGAPREFIX$CNT `)
    if [[ -n ${ANS[@]} ]] ; then
      PASS=1
    fi
    if [[ $PASS -eq 0 ]] ; then
      QUAGGANAME=$QUAGGAPREFIX$CNT 		# Wyszukana wolna nazwa dla nowego routera (kontenera)
      return 0
    fi
  done
  die 5 "Brak wolnych routerów"
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
  for (( CNT=0; CNT<$IFMAX; CNT++ )) ; do
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
    msg2 "Parse IP - poprawne"
    return 0		# IP/mask poprawne
  else
    msg2 "Parse IP - niepoprawne"
    return 1		# IP/mask błędne
  fi
}


# We - $1 IP/Netmask  format:  x.y.z.v/mm 
# We - $2 IP/Netmask
# We - $3 1 Widoczność komunikatów,    0 - brak
# ----------------------------
comparenet() {
  msg2 "Porównanie dwóch adresów sieci  ($1) i ($2)"
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
          msg "Konflikt adresów IP:  $1"
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


# Sprawdza dostępnosc parametrów sieci w podanym kontenerze
# We - $1 IP/Netmask
# We - $2 nazwa kontenera
# ------------------------------------
checkipcnt() {
  msg "Weryfikacja adresu IP $1 w kontenerze $2" 
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

# Sprawdza dostępnosc parametrów sieci we wszystkich kontenerze
# We - $1 IP/Netmask
# ------------------------------------
checkipall() {
  msg "Weryfikacja adresu IP $1 we wszystkich kontenerach" 
  if parseip "$1" ; then

    STAT=1				# Domyslnie IP jest poza adresacja sieci w testowanym kontenerze
    LISTCONTAINER=(`docker ps | sed -n -e '1!p' | awk '{ print $(NF) }' `)
    for (( CNT2=0; CNT2<${#LISTCONTAINER[@]}; CNT2++ )) ; do
      msg2 "="  # rem
      msg2 "=============  kontener  ${LISTCONTAINER[$CNT2]}  ===================" # rem
      LISTIP=(`docker exec ${LISTCONTAINER[$CNT2]} ip a | awk '/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\// {print $2,$(NF)}' `)
#     echo ${LISTIP[@]}
#     echo ${#LISTIP[@]}
      let LISTIPMAX=${#LISTIP[@]}
#     echo $LISTIPMAX
      for (( CNT=0; CNT<$LISTIPMAX; CNT=$CNT+2 )) ; do
  
        if [[ "$1" = "${LISTIP[$CNT]}" ]] ; then
          die 15 "Konflikt adresów IP $1 w kontenerze ${LISTCONTAINER[$CNT2]}"
          return 		# Podane IP jest w konflikcie z IP w danym kontenerze
        fi
#        echo ----- $CNT:  $1   ----  ${LISTIP[$CNT]}    ------
        comparenet "$1" "${LISTIP[$CNT]}"
#        echo ++++ $NET:    $STAT
        case "$NET" in
          "3")
#            echo "check case - podsieci zgodne IP bez konfliktu"
            if [[ "$STAT" -lt "4" ]] ; then 
              STAT=3
            fi ;;
          "2")
#            echo "check case - podsieci rózne"
            if [[ "$STAT" -lt "3" ]] ; then
              STAT=2
            fi ;;
          "1")
#            echo "check case - rozne dlugosci maski"
            if [[ "$STAT" -lt "2" ]] ; then
              STAT=1
            fi ;;
          "0")
#            echo "check case - konflikt adresow"
             die 15 "Konflikt adresów IP $1 w kontenerze ${LISTCONTAINER[$CNT2]}"
            ;;
        esac
      done
    done
    msg "Brak konfliku dla adresu $1"
    return
  elseif
    die 12 "Niepoprawne dane lub format adresu sieci w funkcji <checkip>."
  fi
}

# Zwraca wolny adres IP dla sieci zgodnej z zadanym IP
# uwzgledniajac konfiguracje IP wszystkich kontenerow
# ----------------------------------------------------
# We - $1 Adres IP/Mask do którego ma być wyszukany
#         nowy wolny adres w danej sieci
freeip() {
  comparenet $1 "0.0.0.0"
  msg "Wyszukiwanie wolnego adresu IP w podsieci ${NET1[0]}.${NET1[1]}.${NET1[2]}.${NET1[3]}/$M1"
  msg2 ${M1[@]}  # rem
  msg2 ${IP1[@]}  # rem
  msg2 ${MASK1[@]}  # rem
  msg2 ${NET1[@]}  # rem
  msg2 ${BROADCAST1[@]}  # rem
  msg2 ${NET1[3]}  # rem
  
  NEGM[3]=$[256-${MASK1[3]}]			
  NEGM[2]=$[256-${MASK1[2]}]
  NEGM[1]=$[256-${MASK1[1]}]
  NEGM[0]=$[256-${MASK1[0]}]
  CNTIP=$[NEGM[3]*NEGM[2]*NEGM[1]*NEGM[0]-2]		# obliczanie całkowitej ilości adresów IP w danej sieci

  IM3=$[NET1[3]+1]; IM2=${NET1[2]}; IM1=${NET1[1]}; IM0=${NET1[0]} # Pierwszy adres sieci

  # ---- Dopisanie do listy zarezerwowanych IP, adresów podanych przez użytkownika
  # ------------------------------------------------------------------------------
  unset LISTIM[*]
  if [[ -n ${CFG[5]} ]] ; then
    LISTIM[${#LISTIM[@]}]=${CFG[5]}
  fi
  if [[ -n ${CFG[6]} ]] ; then
    LISTIM[${#LISTIM[@]}]=${CFG[6]}
  fi
  if [[ -n ${CFG[23]} ]] ; then
    LISTIM[${#LISTIM[@]}]=${CFG[23]}
  fi
  if [[ -n ${CFG[24]} ]] ; then
    LISTIM[${#LISTIM[@]}]=${CFG[24]}
  fi

# ----- Wyszukiwanie w kontenerach adresow IP zgodnych z siecią zadanego IP
# ------------------------------------------------------------------------- 
  LISTCONTAINER=(`docker ps | sed -n -e '1!p' | awk '{ print $(NF) }' `)
  for (( CNT2=0; CNT2<${#LISTCONTAINER[@]}; CNT2++ )) ; do
    msg2 "="  # rem
    msg2 "=============  kontener  ${LISTCONTAINER[$CNT2]}  ===================" # rem
    LISTIP=(`docker exec ${LISTCONTAINER[$CNT2]} ip a | awk '/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\// {print $2,$(NF)}' `)
    let LISTIPMAX=${#LISTIP[@]}
    for (( CNT=0; CNT<$LISTIPMAX; CNT=$CNT+2 )) ; do
      msg2 "="  # rem
      msg2 "=============  IP   ${LISTIP[$CNT]}  ==================="  # rem
      msg2  "=============  IP   ${LISTIP[@]}  ==================="  # rem
      for (( I0=$IM0; I0<=${BROADCAST1[0]}; I0++ )) ; do
        for (( I1=$IM1; I1<=${BROADCAST1[1]}; I1++ )) ; do
          for (( I2=$IM2; I2<=${BROADCAST1[2]}; I2++ )) ; do
            for (( I3=$IM3; I3<=$[BROADCAST1[3]-1]; I3++ )) ; do
              msg2 "Memory:  $IM0.$IM1.$IM2.$IM3"  # rem
              comparenet "$I0.$I1.$I2.$I3/$M1" ${LISTIP[$CNT]} "0"
               if [[ "$NET" -eq "1" ]] ; then		
                 msg2 "1a:  $NET"  "$I0.$I1.$I2.$I3/$M1" ${LISTIP[$CNT]}  # rem
                 I3=${BROADCAST1[3]}; I2=${BROADCAST1[2]}; I1=${BROADCAST1[1]}; I0=${BROADCAST1[0]};   # Zakończenie 4 pętli - przejscie do nastepnego IP
                 msg2 "1b:  $NET" "$I0.$I1.$I2.$I3/$M1" ${LISTIP[$CNT]}  # rem
                 if [[ "$CNT" -gt "$LISTIPMAX" ]] ; then
                   CNT2=$[CNT2+1]; CNT=0
                   break
                 fi
               fi              
               if [[ "$NET" -eq "3" ]] ; then
                 msg2 "3a$NET" "$I0.$I1.$I2.$I3/$M1" ${LISTIP[$CNT]}  # rem
                 LISTIM[${#LISTIM[@]}]=${LISTIP[$CNT]}
                 msg2 "Lista IP z podsieci:" ${LISTIM[@]}  # rem
                 IM3=$I3; IM2=$I2; IM1=$I1; IM0=$I0 # Pozostałe sieci przeszukuje od 
						    # od ostatniego wolnego IP
                 I3=${BROADCAST1[3]}; I2=${BROADCAST1[2]}; I1=${BROADCAST1[1]}; I0=${BROADCAST1[0]};
                 msg2 "3b$NET" "$I0.$I1.$I2.$I3/$M1" ${LISTIP[$CNT]}  # rem
               fi
               if [[ "$NET" -eq "2" ]] ; then
                 msg2 "2a$NET" "$I0.$I1.$I2.$I3/$M1" ${LISTIP[$CNT]} # rem
                 I3=${BROADCAST1[3]}; I2=${BROADCAST1[2]}; I1=${BROADCAST1[1]}; I0=${BROADCAST1[0]};
                 msg2 "2b$NET" "$I0.$I1.$I2.$I3/$M1" ${LISTIP[$CNT]} # rem
               fi
            done
          done
        done
      done
    done
  done


  #echo ========================================================================= #rem
  # ----- Wyszukanie pierwszego wolnego IP w zadanej podsieci
  # ---------------------------------------------------------
  I3=$[NET1[3]+1]; I2=${NET1[2]}; I1=${NET1[1]}; I0=${NET1[0]} # Pierwszy adres sieci
  B3=$[BROADCAST1[3]-1]; B2=${BROADCAST1[2]}; B1=${BROADCAST1[1]}; B0=${BROADCAST1[0]}
  CNTMAX=${#LISTIM[@]}; CNT2MAX=${#LISTIM[@]}

  for (( CNT2=0; CNT2<$CNT2MAX; CNT2++ )) ; do
    msg2 " ====  Lista adresow IP używanych w danej podsieci  ====" # rem
    if [[ "${CFG[22]}" -eq "0" ]] ; then
      msg2 "${LISTIM[@]}" # rem
    fi
    msg2 " =========================================================================" # rem
    S=0  			# Status zmieni się jeżeli znajdzie się wolny 
         			# adres IP zakończy się zewnętrzna pętla CNT2
    for (( CNT=0; CNT<$CNTMAX; CNT++ )) ; do
      msg2 "Cykl: $CNT2" # rem
      msg2 "====  IP  ${LISTIM[$CNT]}  ====" # rem
      comparenet "$I0.$I1.$I2.$I3/$M1" ${LISTIM[$CNT]} "0"
      if [[ "$NET" -eq "0" ]] ; then
        S=1
        msg2 "====  Zgodne IP - $I0.$I1.$I2.$I3/$M1 - przesunieice na koniec listy" # rem
        # Zamiana pozycji miejscami - skraca czas wyszukiwania
        CNTMAX2=$[CNTMAX-1]
        TMP=${LISTIM[$CNT]}; LISTIM[$CNT]=${LISTIM[$CNTMAX2]}; LISTIM[$CNTMAX2]=$TMP   
        CNTMAX=$[CNTMAX-1]      # Nie przeszukuje powtornie znalezionego zgodnego adresu
        if [[ "$I3" -lt "$B3" ]] ; then
          I3=$[I3+1]              
        else
          I3=$[NET1[3]+1]
          if [[ "$I2" -lt "$B2" ]] ; then
            I2=$[I2+1]
          else
            I2=$[NET1[2]+1]
            if [[ "$I1" -lt "$B1" ]] ; then
              I1=$[I1+1]
            else
              I1=$[NET1[1]+1]
              if [[ "$I0" -lt "$B0" ]] ; then
                I0=$[I0+1]
              else
                die 28 "======== BRAK WOLNEGO ADRESU IP W PODANEJ SIECI ======="
              fi
            fi
          fi 
        fi
        msg2 "====  Nastepne IP do sprawdzenia: $I0.$I1.$I2.$I3/$M1" # rem
      fi
      
    done
    if [[ "$S" -eq "0" ]] ; then
      CNT2=CNT2MAX
    fi
  done
  NEWIP="$I0.$I1.$I2.$I3/$M1"
  msg2 " -----------------------------------" # rem
  msg2 " WOLNY ADRES IP:  $NEWIP" # rem
  msg2 " -----------------------------------" # rem
  msg "Rezerwacja adresu IP: $NEWIP"
 return 0
}


# Zwraca adres nowej podsieci uwzgledniajac konfiguracje IP wszystkich kontenerow
# -------------------------------------------------------------------------------
freenet() {
  comparenet $DEFAULTNET "0.0.0.0"
  msg "Wyszukiwanie wolnego adresu sieci. Domyślny: ${NET1[0]}.${NET1[1]}.${NET1[2]}.${NET1[3]}/$M1"
  msg2 ${M1[@]}  # rem
  msg2 ${IP1[@]}  # rem
  msg2 ${MASK1[@]}  # rem
  msg2 ${NET1[@]}  # rem
  msg2 ${BROADCAST1[@]}  # rem
  NEGM[3]=$[256-${MASK1[3]}]			
  NEGM[2]=$[256-${MASK1[2]}]
  NEGM[1]=$[256-${MASK1[1]}]
  NEGM[0]=$[256-${MASK1[0]}]
  CNTIP=$[NEGM[3]*NEGM[2]*NEGM[1]*NEGM[0]-2]		# obliczanie całkowitej ilości adresów IP w danej sieci

  NETM[3]=${NET1[3]}; NETM[2]=${NET1[2]}; NETM[1]=${NET1[1]}; NETM[0]=${NET1[0]} # Adres sieci

# ----- Wyszukiwanie w kontenerach adresow sieci o masce zgodnej z domyślnym adresem sieci
# ----------------------------------------------------------------------------------------

  LISTCONTAINER=(`docker ps | sed -n -e '1!p' | awk '{ print $(NF) }' `)
  for (( CNT2=0; CNT2<${#LISTCONTAINER[@]}; CNT2++ )) ; do
    msg2 "="  # rem
    msg2 "=============  kontener  ${LISTCONTAINER[$CNT2]}  ===================" # rem
    LISTIP=(`docker exec ${LISTCONTAINER[$CNT2]} ip a | awk '/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\// {print $2,$(NF)}' `)
    let LISTIPMAX=${#LISTIP[@]}
    for (( CNT=0; CNT<$LISTIPMAX; CNT=$CNT+2 )) ; do
      msg2 "="  # rem
      msg2 "-----  IP   ${LISTIP[$CNT]}  -----"  # rem
      M2=(`echo ${LISTIP[$CNT]} | awk -F/ '{print $2}' `)
      if [[ "$M1" -eq "$M2" ]] ; then
        LISTIM[${#LISTIM[@]}]=${LISTIP[$CNT]}
      fi
    done
    if [[ ${CFG[22]} == "0" ]] ; then
      echo "LISTA: ${LISTIM[@]}"
    fi
  done

  # ----- Wyszukanie pierwszej wolnej sieci z domyślnego zekresu
  # ------------------------------------------------------------
  CNTMAX=${#LISTIM[@]}; CNT2MAX=${#LISTIM[@]}

  S2=1
 # for (( CNT2=0; CNT2<$CNT2MAX; CNT2++ )) ; do
  while [ $S2 -eq 1 ] ; do

    S=0  			# Status zmieni się jeżeli znajdzie się wolny 
         			# adres IP zakończy się zewnętrzna pętla CNT2

    for (( CNT=0; CNT<$CNTMAX; CNT++ )) ; do
      msg2 "Cykl: $CNT2 of $CNT2MAX : poz: $CNT of $CNTMAX" # rem
      msg2 "====  IP  ${LISTIM[$CNT]}  ====" # rem
      comparenet "${NETM[0]}.${NETM[1]}.${NETM[2]}.${NETM[3]}/$M1" ${LISTIM[$CNT]} "0"
      msg2 ${M1[@]}  # rem
      msg2 ${IP1[@]}  # rem
      msg2 ${MASK1[@]}  # rem
      msg2 ${NET1[@]}  # rem
      msg2 ${BROADCAST1[@]}  # rem
      if [[ "$NET" -eq "0" ]] || [[ "$NET" -eq "3" ]] ; then
        S=1     # Wymusza kolejne sprawdzenie listy dla kolejnej sieci
        msg2 "====  Zgodny adres sieci - ${NET1[@]}/$M1 - usunięcie z listy" # rem
        # Usunięcie pozycji skraca czas wyszukiwania
        CNT2MAX=$[CNT2MAX-1]
        
        LISTIM[$CNT]=${LISTIM[$CNT2MAX]}; LISTIM[$CNT2MAX]=""

        if [[ "${CFG[22]}" == "0" ]] ; then 
          echo "===  $CNT2 of $CNT2MAX : $CNT of $CNTMAX : ${LISTIM[$CNT2MAX]} " # rem
          echo "${LISTIM[@]} " # rem
        fi
        CNTMAX=$[CNTMAX-1]      # Nie przeszukuje powtornie znalezionego zgodnego adresu
        CNT=$[CNT-1]            # Powtórnie przeszukuje ostatnią pozycje z nowo wstawionym elementem
      fi
 

    done

    if [[ "$S" == "0" ]] ; then  # Znacznik określający czy aktualny ustalony adres sieci
         			  # ( NETM[@] jest wolny. Gdy S=0, pętla while kończy działanie.
				  # Gdy S=1, ustala kolejny adres sieci zgodnie z maską.
#      CNT2=$CNT2MAX
       S2=0
    else
    # ----- Ustalenieadresu kolejnej sieci z zadaną długością maski
      if [[ "${MASK1[3]}" -ne "0" ]] ; then
        if [[ "$[NETM[3]+NEGM[3]]" -lt "256" ]] ; then
          NETM[3]=$[NETM[3]+NEGM[3]]
        else
          NETM[3]=0
          if [[ "$[NETM[2]+NEGM[2]]" -lt "256" ]] ; then
            NETM[2]=$[NETM[2]+NEGM[2]]
          else
            NETM[2]=0
            if [[ "$[NETM[1]+NEGM[1]]" -lt "256" ]] ; then
              NETM[1]=$[NETM[1]+NEGM[1]]
            else
              NETM[1]=0
              if [[ "$[NETM[0]+NEGM[0]]" -lt "256" ]] ; then
                NETM[0]=$[NETM[0]+NEGM[0]]
              else
                die 28 "======== BRAK WOLNEj SIECI IP W PODANYM ZAKRESIE MASKI ======="
              fi
            fi
          fi     
        fi
      else
        if [[ "${MASK1[2]}" -ne "0" ]] ; then
          if [[ "$[NETM[2]+NEGM[2]]" -lt "256" ]] ; then
            NETM[2]=$[NETM[2]+NEGM[2]]
          else
            NETM[2]=0
            if [[ "$[NETM[1]+NEGM[1]]" -lt "256" ]] ; then
              NETM[1]=$[NETM[1]+NEGM[1]]
            else
              NETM[1]=0
              if [[ "$[NETM[0]+NEGM[0]]" -lt "256" ]] ; then
                 NETM[0]=$[NETM[0]+NEGM[0]]
               else
                 die 28 "======== BRAK WOLNEj SIECI IP W PODANYM ZAKRESIE MASKI ======="
              fi
            fi
          fi
        else
          if [[ "${MASK1[1]}" -ne "0" ]] ; then
            if [[ "$[NETM[1]+NEGM[1]]" -lt "256" ]] ; then
              NETM[1]=$[NETM[1]+NEGM[1]]
            else
              NETM[1]=0
              if [[ "$[NETM[0]+NEGM[0]]" -lt "256" ]] ; then
                NETM[0]=$[NETM[0]+NEGM[0]]
              else
                die 28 "======== BRAK WOLNEj SIECI IP W PODANYM ZAKRESIE MASKI ======="
              fi
            fi
          else
            if [[ "${MASK1[0]}" -ne "0" ]] ; then
              if [[ "$[NETM[0]+NEGM[0]]" -lt "256" ]] ; then
                NETM[0]=$[NETM[0]+NEGM[0]]
              else
                die 28 "======== BRAK WOLNEj SIECI IP W PODANYM ZAKRESIE MASKI ======="
              fi
            fi
          fi
        fi
      fi
    fi
    msg2 "====  Nastepna sieć do sprawdzenia: ${NETM[@]}/$M1" # rem
  done

  NEWNET="${NETM[0]}.${NETM[1]}.${NETM[2]}.${NETM[3]}/$M1"
  msg2 " -----------------------------------" # rem
  msg2 " Wolny adres sieci IP: $NEWNET"
  msg2 " -----------------------------------" # rem
  msg "Rezerwacja adresu sieci: $NEWNET"
 return 0
}



# ---- Przypisanie nazwy dla kontenera <c>
set_c() {
if [[ -z ${CFG[0]} ]] ; then
  if freecontainer ; then 
    CFG[0]=$QOSNAME
    msg "Przypisano nazwę kontenera -c: <${CFG[0]}>"
  fi
fi
return 0
}

# ---- Przypisanie nazwy dla routera Quagga <r1>
set_r1() {
if [[ "${CFG[18]}" == "setnamecntquagga" ]] ; then
  if freerouter ; then 
    CFG[18]=$QUAGGANAME
    msg "Przypisano nazwę routera w kontenerze -r1: <${CFG[18]}>"
  fi
fi
return 0
}

# ---- Przypisanie nazwy dla routera Quagga <r2>
set_r2() {
if [[ "${CFG[19]}" == "setnamecntquagga" ]] ; then
  if freerouter ; then 
    CFG[19]=$QUAGGANAME
    msg "Przypisano nazwę routera w kontenerze -r2: <${CFG[19]}>"
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

# -----  Przypisanie nazwy dla interfejsu <if2> w hoscie <-h2>  -------
set_if2() {
if [[ -z ${CFG[4]} ]] ; then
  if freeinterface "${CFG[2]}" ; then
    CFG[4]=$IFNAME
    msg "Przypisano nazwę interfejsu -if2: <${CFG[4]}> w kontenerze <${CFG[2]}>"
  fi
fi
return 0
}

# -----  Przypisanie nazwy dla interfejsu <if1> w routerze <-r1>  -------
set_if1r1() {
if [[ -z ${CFG[3]} ]] ; then
  if freeinterface "${CFG[18]}" ; then
    CFG[3]=$IFNAME
    msg "Przypisano nazwę interfejsu -if1: <${CFG[3]}> w kontenerze <${CFG[18]}>"
  fi
fi
return 0
}

# -----  Przypisanie nazwy dla interfejsu <if2> w routerze <-r2>  -------
set_if2r2() {
if [[ -z ${CFG[4]} ]] ; then
  if freeinterface "${CFG[19]}" ; then
    CFG[4]=$IFNAME
    msg "Przypisano nazwę interfejsu -if2: <${CFG[4]}> w kontenerze <${CFG[19]}>"
  fi
fi
return 0
}

# -----  Przypisanie nazwy dla interfejsu <if3> w kontenerze linku <-c>  -------
set_if3() {
if [[ -z ${CFG[25]} ]] ; then
  if freeinterface "${CFG[0]}" ; then
    CFG[25]=$IFNAME
    msg "Przypisano nazwę interfejsu -if3: <${CFG[25]}> w kontenerze <${CFG[0]}>"
  fi
fi
return 0
}

# -----  Przypisanie nazwy dla interfejsu <if4> w kontenerze linku <-c>  -------
set_if4() {
if [[ -z ${CFG[26]} ]] ; then
  if freeinterface "${CFG[0]}" ; then
    CFG[26]=$IFNAME
    msg "Przypisano nazwę interfejsu -if4: <${CFG[26]}> w kontenerze <${CFG[0]}>"
  fi
fi
return 0
}

# -----  Uruchomienie kontenera łączącego hosty ( QoSLink )
crt_c() {
  docker run -d -ti --name ${CFG[0]} --hostname ${CFG[0]} --cap-add NET_ADMIN qoslink:v1 /bin/bash
  msg "Uruchomienie kontenera łączącego ${CFG[0]}"
}

# -----  Uruchomienie kontenera -r1 - Router Quagga ( QoSQuagga )
crt_r1() {
  docker run -d -ti --name ${CFG[18]} --hostname ${CFG[18]} --cap-add NET_ADMIN host:v1 /bin/bash
  msg "Uruchomienie routera Quagga w kontenerze ${CFG[18]}"
}

# -----  Uruchomienie kontenera -r2 - Router Quagga ( QoSQuagga )
crt_r2() {
  docker run -d -ti --name ${CFG[19]} --hostname ${CFG[19]} --cap-add NET_ADMIN host:v1 /bin/bash
  msg "Uruchomienie routera Quagga w kontenerze ${CFG[19]}"
}


# -----  Tworzenie połączen pomiędzy bridgem a kontenerem
crt_linkif1() {
  pipework ${CFG[7]} -i ${CFG[3]} ${CFG[1]} ${CFG[5]}
  msg "Polaczenie bridg'a -br1 ${CFG[7]} z hostem ${CFG[1]}"
}

crt_linkif2() {
  pipework ${CFG[8]} -i ${CFG[4]} ${CFG[2]} ${CFG[6]}
  msg "Polaczenie bridg'a -br1 ${CFG[8]} z hostem ${CFG[2]}"
}

crt_linkif3() {
  pipework ${CFG[7]} -i ${CFG[25]} ${CFG[0]} ${CFG[23]}
  msg "Polaczenie bridg'a -br1 ${CFG[7]} z hostem ${CFG[0]}"
}

crt_linkif4() {
  pipework ${CFG[8]} -i ${CFG[26]} ${CFG[0]} ${CFG[24]}
  msg "Polaczenie bridg'a -br1 ${CFG[8]} z hostem ${CFG[0]}"
}

crt_linkif1r1() {
  pipework ${CFG[7]} -i ${CFG[3]} ${CFG[18]} ${CFG[5]}
  msg "Polaczenie bridg'a -br1 ${CFG[7]} z hostem ${CFG[18]}"
}

crt_linkif2r2() {
  pipework ${CFG[8]} -i ${CFG[4]} ${CFG[19]} ${CFG[6]}
  msg "Polaczenie bridg'a -br1 ${CFG[8]} z hostem ${CFG[19]}"
}


# ----  Utworzenie bridga br0 wewnątrz kontenera <qoslinkxx>
# ----  umożliwia przekazywanie pakietów poprzez kontener <qoslinkxx>
# ----  z zachowaniem zadanych parametrów transmisji
crt_brinqos() {
msg "Utworzenie bridga br0 w kontenerze ${CFG[0]} mostkujący intefejsy ${CFG[25]} oraz ${CFG[26]}"
ANS=(`docker exec ${CFG[0]} ip addr flush dev ${CFG[25]}`)
ANS=(`docker exec ${CFG[0]} ip addr flush dev ${CFG[26]}`)
ANS=(`docker exec ${CFG[0]} ip link set dev ${CFG[25]} up`)
ANS=(`docker exec ${CFG[0]} ip link set dev ${CFG[26]} up`)
ANS=(`docker exec ${CFG[0]} brctl addbr br0`)
ANS=(`docker exec ${CFG[0]} brctl addif br0 ${CFG[25]}`)
ANS=(`docker exec ${CFG[0]} brctl addif br0 ${CFG[26]}`)
ANS=(`docker exec ${CFG[0]} ip addr add ${CFG[23]} dev br0`)
ANS=(`docker exec ${CFG[0]} ip link set dev br0 up`)
}

set_link() {
set -x
msg "Kofiguracja parametrów łącza: Pasmo ${CFG[9]}/${CFG[10]} z opóżnieniem ${CFG[13]}/${CFG[14]}"
#ANS=(`docker exec ${CFG[0]} tc qdisc del root dev ${CFG[25]}`)
#ANS=(`docker exec ${CFG[0]} tc qdisc del root dev ${CFG[26]}`)
ANS=(`docker exec ${CFG[0]} tc qdisc add dev ${CFG[25]} root handle 1:0 tbf rate ${CFG[9]} latency 100ms burst 50k`)
ANS=(`docker exec ${CFG[0]} tc qdisc add dev ${CFG[26]} root handle 1:0 tbf rate ${CFG[10]} latency 100ms burst 50k`)
ANS=(`docker exec ${CFG[0]} tc qdisc add dev ${CFG[25]} parent 1:1 handle 10:0 netem delay ${CFG[13]} loss ${CFG[11]} duplicate ${CFG[28]} `)
ANS=(`docker exec ${CFG[0]} tc qdisc add dev ${CFG[26]} parent 1:1 handle 10:0 netem delay ${CFG[14]} loss ${CFG[12]} duplicate ${CFG[29]} `)
set +x
}

del_container() {
  if [[ "${CFG[27]}" = "deldefaultnamecnt" ]] ; then
   : # :
  fi
}

checklink() {
: # :
}



# ---------------------------------------------------------------------------------------------
#   QoSLink - skrypt symulujący sieć IP składającą się z łączy, switchy oraz routerów 
#             wraz z ustalaniem parametrów transmisji <przepustowości, opóźnienia,
#             gubienia oraz duplikowania pakietów niezależnie dla poszczególnych łączy.
#             Działanie skryptu oparte jest na technologii kontenerów Docker, 
#             routingu opartego na oprogramowaniu Quagga,Traffic Control (TC), module NetEM,
#             skrypcie pipework autorstwa ............... udostępnionego na licencji ......
# ---------------------------------------------------------------------------------------------
#
#   Tablica z dostępnymi opcjami oraz parametrami wejściowymi dla skyptu
#   | 0 | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9    | 10   | 11   | 12   | 13    | 14    | 15  | 16 | 17 | 18 | 19 | 20 | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28     | 29 )
WSK=(-c  -h1  -h2  -if1 -if2 -ip1 -ip2 -br1 -br2 -band1 -band2 -loss1 -loss2 -delay1 -delay2 -link -sw1 -sw2 -r1  -r2  -U   -v   -V   -ip3 -ip4 -if3 -if4 -D   -duplic1 -duplic2)
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

      if [ ${PARAM[$CNT]} = "-update" ] ; then		# Zapis dotyczący  aktualizacji danych 
        CFG[$CNT2]=0
      fi

      if [ ${PARAM[$CNT]} = "-v" ] ; then		# Zapis dotyczacy wyswietlen komunikatow
        CFG[$CNT2]=0
      fi

      if [ ${PARAM[$CNT]} = "-V" ] ; then		# Zapis dotyczacy wyswietlen komunikatow debugowania
        CFG[$CNT2]=0
      fi

      if [ ${PARAM[$CNT]} = "-D" ] ; then		# Zapis dotyczacy usuwania kontenerów
        CFG[$CNT2]=0
      fi

      TMP=${CFG[$CNT2]}
      TMP=${TMP:0:1}
      if [ ${PARAM[$CNT]} = "-r1" ] ; then		# Zapis dotyczacy automatycznego nazwania routera
        if [[ -n ${CFG[$CNT2]} ]] ; then
          if [[ "$TMP" = "-" ]] ; then
            CFG[$CNT2]="setnamecntquagga"
          fi
        else
          CFG[$CNT2]="setnamecntquagga"
        fi
      fi

      if [ ${PARAM[$CNT]} = "-r2" ] ; then		# Zapis dotyczacy automatycznego nazwania routera
        if [[ -n ${CFG[$CNT2]} ]] ; then
          if [[ "$TMP" = "-" ]] ; then
            CFG[$CNT2]="setnamecntquagga"
          fi
        else
          CFG[$CNT2]="setnamecntquagga"
        fi
      fi

      if [ ${PARAM[$CNT]} = "-D" ] ; then		# Zapis dotyczacy automatycznego nazwania routera
        if [[ -n ${CFG[$CNT2]} ]] ; then
          if [[ "$TMP" = "-" ]] ; then
            CFG[$CNT2]="deldefaultnamecnt"
          fi
        else
          CFG[$CNT2]="deldefaultnamecnt"
        fi
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

# -----  Weryfikacja interfejsu  IF1  -----
if [[ -n ${CFG[3]} ]] ; then
  if checkinterface "${CFG[3]}" "${CFG[1]}" ; then
    die 5 "Nazwa interfejsu z opcji -if1 ${CFG[3]} jest już utworzona w kontenerze ${CFG[1]}"
  fi
fi

# -----  Weryfikacja interfejsu  IF2  -----
if [[ -n ${CFG[4]} ]] ; then
  if checkinterface "${CFG[4]}" "${CFG[2]}" ; then
    die 5 "Nazwa interfejsu z opcji -if2 ${CFG[4]} jest już utworzona w kontenerze ${CFG[2]}"
  fi
fi

# -----  Weryfikacja interfejsu  IF3  -----
if [[ -n ${CFG[25]} ]] ; then
  if checkinterface "${CFG[25]}" "${CFG[1]}" ; then
    die 5 "Nazwa interfejsu z opcji -if3 ${CFG[25]} jest już utworzona w kontenerze ${CFG[1]}"
  fi
fi

# -----  Weryfikacja interfejsu  IF4  -----
if [[ -n ${CFG[26]} ]] ; then
  if checkinterface "${CFG[26]}" "${CFG[2]}" ; then
    die 5 "Nazwa interfejsu z opcji -if4 ${CFG[26]} jest już utworzona w kontenerze ${CFG[2]}"
  fi
fi

# ----  Weryfikacja poprawności IP1
if [[ -n ${CFG[5]} ]] ; then
  if ! parseip ${CFG[5]}  ; then
    die 8 "Niepoprawny format parametrow sieci dla -ip1. (format: x.y.z.v/mask) mask:<1,29>"
  fi
fi

# ----  Weryfikacja poprawności IP2
if [[ -n ${CFG[6]} ]] ; then
  if ! parseip ${CFG[6]}  ; then
    die 8 "Niepoprawny format parametrow sieci dla -ip2. (format: x.y.z.v/mask) mask:<1,29>"
  fi
fi

# ----  Weryfikacja parametru pasma 1 - BAND1
if [[ -z ${CFG[9]} ]] ; then
  CFG[9]="100Mbit"
fi

# ----  Weryfikacja parametru pasma 2 - BAND2
if [[ -z ${CFG[10]} ]] ; then
  CFG[10]="100Mbit"
fi

# ----  Weryfikacja parametru utraty pakietów - LOSS1
if [[ -z ${CFG[11]} ]] ; then
  CFG[11]="0.1%"
fi

# ----  Weryfikacja parametru utraty pakietów - LOSS2
if [[ -z ${CFG[12]} ]] ; then
  CFG[12]="0.1%"
fi

# ----  Weryfikacja parametru opóżnienia - DELAY1
if [[ -z ${CFG[13]} ]] ; then
  CFG[13]="1ms"
fi

# ----  Weryfikacja parametru opóżnienia - DELAY2
if [[ -z ${CFG[14]} ]] ; then
  CFG[14]="1ms"
fi

# ----  Weryfikacja parametru duplicowania - DUPLIC1
if [[ -z ${CFG[28]} ]] ; then
  CFG[28]="1%"
fi

# ----  Weryfikacja parametru duplicowania - DUPLIC2
if [[ -z ${CFG[29]} ]] ; then
  CFG[29]="1%"
fi

# ----  Weryfikacja nazwy łącza - LINK
if [[ -n ${CFG[15]} ]] ; then
  if ! checklink ${CFG[15]}  ; then
    die 8 "Niepoprawna nazwa łącza"
  fi
fi



# ----  Usuwanie kontenerów
if [[ -n ${CFG[27]} ]] ; then
  del_container
  echo "Funkcja do zaprogramowania"
  exit
fi

# Podgląd tablicy z parametrami
# ---------------------
for (( CNT=0; CNT<${#WSK[@]}; CNT++ )) ; do
  echo "CFG[$CNT] -eq ${CFG[$CNT]} " 
done


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
if [[ -n ${CFG[16]} ]] ; then
  let KOD=$KOD+8   ; fi
if [[ -n ${CFG[17]} ]] ; then
  let KOD=$KOD+4   ; fi
if [[ -n ${CFG[18]} ]] ; then
  let KOD=$KOD+2   ; fi
if [[ -n ${CFG[19]} ]] ; then
  let KOD=$KOD+1   ; fi
#echo ---- $KOD ----

case "$KOD" in

66)						#       h2  ---  r1
    freenet
    freeip $NEWNET
    CFG[5]=$NEWIP
    freeip $NEWNET
    CFG[6]=$NEWIP
    freeip $NEWNET
    CFG[23]=$NEWIP
    freeip $NEWNET
    CFG[24]=$NEWIP
    set_c
    set_r1
    set_br1
    set_br2
    crt_c
    crt_r1
    set_if1r1
    crt_linkif1r1
    set_if2
    crt_linkif2
    set_if3
    crt_linkif3
    set_if4
    crt_linkif4
    crt_brinqos
    set_link
    ;;

129)						# h1        ---       r2
    freenet
    freeip $NEWNET
    CFG[5]=$NEWIP
    freeip $NEWNET
    CFG[6]=$NEWIP
    freeip $NEWNET
    CFG[23]=$NEWIP
    freeip $NEWNET
    CFG[24]=$NEWIP
    set_c
    set_r2
    set_br1
    set_br2
    crt_c
    crt_r2
    set_if1
    crt_linkif1
    set_if2r2
    crt_linkif2r2
    set_if3
    crt_linkif3
    set_if4
    crt_linkif4
    crt_brinqos
    set_link
    ;;

224)						# h1 + ip1  ---  h2 
    checkipall ${CFG[5]}
    freeip ${CFG[5]}
    CFG[6]=$NEWIP
    freeip ${CFG[5]}
    CFG[23]=$NEWIP
    freeip ${CFG[6]}
    CFG[24]=$NEWIP
    set_c
    set_br1
    set_br2
    crt_c
    set_if1
    crt_linkif1
    set_if2
    crt_linkif2
    set_if3
    crt_linkif3
    set_if4
    crt_linkif4
    crt_brinqos
    set_link
    ;;

161)						# h1 + ip1  ---         r2
    checkipall ${CFG[5]}
    freeip ${CFG[5]}
    CFG[6]=$NEWIP
    freeip ${CFG[5]}
    CFG[23]=$NEWIP
    freeip ${CFG[5]}
    CFG[24]=$NEWIP
    set_c
    set_r2
    set_br1
    set_br2
    crt_c
    crt_r2
    set_if1
    crt_linkif1
    set_if2r2
    crt_linkif2r2
    set_if3
    crt_linkif3
    set_if4
    crt_linkif4
    crt_brinqos
    set_link
    ;;


208)						# h1        ---  h2 + ip2  
    checkipall ${CFG[6]}
    freeip ${CFG[6]}
    CFG[5]=$NEWIP
    freeip ${CFG[5]}
    CFG[23]=$NEWIP
    freeip ${CFG[6]}
    CFG[24]=$NEWIP
    set_c
    set_br1
    set_br2
    crt_c
    set_if1
    crt_linkif1
    set_if2
    crt_linkif2
    set_if3
    crt_linkif3
    set_if4
    crt_linkif4
    crt_brinqos
    set_link
    ;;

82)						# h1 + ip1  ---         r2
    checkipall ${CFG[6]}
    freeip ${CFG[6]}
    CFG[5]=$NEWIP
    freeip ${CFG[6]}
    CFG[23]=$NEWIP
    freeip ${CFG[6]}
    CFG[24]=$NEWIP
    set_c
    set_r1
    set_br1
    set_br2
    crt_c
    crt_r1
    set_if1r1
    crt_linkif1r1
    set_if2
    crt_linkif2
    set_if3
    crt_linkif3
    set_if4
    crt_linkif4
    crt_brinqos
    set_link
    ;;

240)						# h1 + ip1  ---  h2 + ip2  
    comparenet "${CFG[5]}" "${CFG[6]}" "1"
    if [[ "$NET" -eq "3" ]] ; then
      checkipall ${CFG[5]}
      checkipall ${CFG[6]}
      freeip ${CFG[5]}
      CFG[23]=$NEWIP
      freeip ${CFG[6]}
      CFG[24]=$NEWIP
      set_c
      set_br1
      set_br2
      crt_c
      set_if1
      crt_linkif1
      set_if2
      crt_linkif2
      set_if3
      crt_linkif3
      set_if4
      crt_linkif4
      crt_brinqos
      set_link
    else     
      exit 0
    fi
    ;;

51)						# h1 + ip1  ---  h2 + ip2  
    comparenet "${CFG[5]}" "${CFG[6]}" "1"
    if [[ "$NET" -eq "3" ]] ; then
      checkipall ${CFG[5]}
      checkipall ${CFG[6]}
      freeip ${CFG[5]}
      CFG[23]=$NEWIP
      freeip ${CFG[6]}
      CFG[24]=$NEWIP
      set_c
      set_br1
      set_br2
      crt_c
      set_r1
      crt_r1
      set_r2
      crt_r2
      set_if1r1
      crt_linkif1r1
      set_if2r2
      crt_linkif2r2
      set_if3
      crt_linkif3
      set_if4
      crt_linkif4
      crt_brinqos
      set_link
    else     
      exit 0
    fi
    ;;

192)
    freenet
    freeip $NEWNET
    CFG[5]=$NEWIP
    freeip $NEWNET
    CFG[6]=$NEWIP
    freeip $NEWNET
    CFG[23]=$NEWIP
    freeip $NEWNET
    CFG[24]=$NEWIP
    set_c
    set_br1
    set_br2
    crt_c
    set_if1
    crt_linkif1
    set_if2
    crt_linkif2
    set_if3
    crt_linkif3
    set_if4
    crt_linkif4
    crt_brinqos
    set_link
    ;;
*)
    echo "Nieprawidłowe zestawienie parametrów."
    exit 0 ;;  
esac

# Podgląd tablicy z parametrami
# ---------------------
for (( CNT=0; CNT<${#WSK[@]}; CNT++ )) ; do
  echo "CFG[$CNT] -eq ${CFG[$CNT]} " 
done

echo Koniec
exit 0


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

