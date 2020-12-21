#!/bin/bash
set -e

#  set +x

# Zmienne Globalne
# ----------------
BRPREFIX="brlink"	# Domyślne nazwy bridgy, linków oraz interfejsów
BRMAX=512		# tworzonych w tych kontenerach.
QOSPREFIX="qoslink"
QOSMAX=256
IFPREFIX="eth"
IFMAX=32
NETDEFAULT="10.1.1.0/24" # Domyślny adres sieci. Obsluga 254 sieci.


# Komentarze i błędy
# ------------------------------
msg () {			# Komentarze wyswietlane przy ustawionej opcji  -v
  if [[ ${CFG[21]} ]] ; then
    echo $1$2$3
  fi
}

msg2 () {			# Komunikaty debugowania wyswietlane przy ustawionej opcji  -V
  if [[ ${CFG[22]} ]] ; then
    echo $1$2$3
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
    msg "Brak konfliku adresu dla adresu $1"
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
    if [[ ${CFG[22]} ]] ; then
      echo "${LISTIM[@]}" # rem
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
  docker run -d -ti --name ${CFG[0]} --hostname ${CFG[0]} --cap-add NET_ADMIN host:v1 /bin/bash
  msg "Uruchomienie kontenera linka ${CFG[0]}"
}


# -----  Utworzenie połączenia pomiędzy  bridgem a kontenerem
# $1 - bridge
# $2 - interface
# $3 - host
# $4 - adres IP
crt_link() {
  pipework $1 -i $2 $3 $4
  #pipework ${CFG[7]} -i ${CFG[3]} ${CFG[1]} ${CFG[5]}
  msg "Polaczenie bridg'a -br1 $1 z hostem $3"
}

# ----  Utworzenie bridga br0 wewnątrz kontenera <qoslinkxx>
# ----  umożliwia przekazywanie pakietów poprzez kontener <qoslinkxx>
# ----  z zachowaniem zadanych parametrów transmisji
# $1 - nazwa kontenera
# $2 - nazwa interfejsu -if3
# $3 - nazwa interfejsu -if4
# $4 - adres IP - ip1  dla bridga br0
crt_brinqos() {
msg "Utworzenie bridga br0 w kontenerze $1 mostkujący intefejsy $2 oraz $3"
ANS=(`docker exec $1 ip addr flush dev $2`)
ANS=(`docker exec $1 ip addr flush dev $3`)
ANS=(`docker exec $1 ip link set dev $2 up`)
ANS=(`docker exec $1 ip link set dev $3 up`)
ANS=(`docker exec $1 brctl addbr br0`)
ANS=(`docker exec $1 brctl addif br0 $2`)
ANS=(`docker exec $1 brctl addif br0 $3`)
ANS=(`docker exec $1 ip addr add $4 dev br0`)
ANS=(`docker exec $1 ip link set dev br0 up`)
}

# Weryfikacja wprowadzonych parametrów i ich zależności
# -----------------------------------------------------
# ---------------------------------------------------------------------------------------------
#   QoSLink - skrypt symulujący sieć składającą się z łączy, switchy oraz routerów 
#             wraz z ustalaniem parametrów transmisji <przepustowości, opóźnienia,
#             gubienia oraz duplikowania pakietów niezależnie dla poszczególnych łączy.
#             Działanie skryptu oparte jest na technologii kontenerów Docker, 
#             routingu opartego na oprogramowaniu Quagga,Traffic Control (TC), module NetEM,
#             skrypcie pipework autorstwa ............... udostępnionego na licencji ......
# ---------------------------------------------------------------------------------------------
#
#   Tablica z dostępnymi opcjami oraz parametrami wejściowymi dla skyptu
#   | 0 | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9    | 10   | 11   | 12   | 13    | 14    | 15  | 16 | 17 | 18 | 19 | 20    | 21 | 22 | 23 | 24 | 25 | 26 )
WSK=(-c  -h1  -h2  -if1 -if2 -ip1 -ip2 -br1 -br2 -band1 -band2 -loss1 -loss2 -delay1 -delay2 -link -sw1 -sw2 -r1  -r2  -update -v   -V   -ip3 -ip4 -if3 -if4 )
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
      if [ ${PARAM[$CNT]} = "-V" ] ; then		# Zapis dotyczacy wyswietlen komunikatow debugowania
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

# -----  Weryfikacja interfejsow  -----
if [[ -n ${CFG[25]} ]] ; then
  if checkinterface "${CFG[25]}" "${CFG[1]}" ; then
    die 5 "Nazwa interfejsu z opcji -if3 ${CFG[25]} jest już utworzona w kontenerze ${CFG[1]}"
  fi
fi

if [[ -n ${CFG[26]} ]] ; then
  if checkinterface "${CFG[26]}" "${CFG[2]}" ; then
    die 5 "Nazwa interfejsu z opcji -if4 ${CFG[26]} jest już utworzona w kontenerze ${CFG[2]}"
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
      crt_link ${CFG[7]} ${CFG[3]} ${CFG[1]} ${CFG[5]}
      set_if2
      crt_link ${CFG[8]} ${CFG[4]} ${CFG[2]} ${CFG[6]}
      set_if3
      crt_link ${CFG[7]} ${CFG[25]} ${CFG[0]} ${CFG[23]}
      set_if4
      crt_link ${CFG[8]} ${CFG[26]} ${CFG[0]} ${CFG[24]}
      crt_brinqos ${CFG[0]} ${CFG[25]} ${CFG[26]} ${CFG[23]}
    else
      
      exit 0
    fi
    ;;

*)
    echo "Nieprawidłowe zestawienie parametrów."
    exit 0 ;;  
esac

# Podgląd tablicy z parametrami
# ---------------------
#for (( CNT=0; CNT<${#WSK[@]}; CNT++ )) ; do
#  echo "CFG[$CNT] -eq ${CFG[$CNT]} " 
#done

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

