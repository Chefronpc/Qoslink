#!/bin/bash

# Parametry wstępne -  Globalne
# ----------------
BRPREFIX="brlink"	# Domyślne nazwy bridgy, switchy, linków, routerów oraz interfejsów
BRMAX=512		# tworzonych w tych kontenerach.
SWPREFIX="brswitch"
SWMAX=512
QOSPREFIX="qoslink"
QOSMAX=256
QUAGGAPREFIX="quaggalink"
QUAGGAMAX=256
IFPREFIX="eth"
IFMAX=64
DEFAULTNET="10.0.0.0/24" # Domyślny adres sieci. Obsluga pełnego zakresu adresacji sieci

R="\e[31m"  # Kolory komunikatów
Y="\e[33m"
G="\e[32m"
B="\e[34m"
BCK="\e[0m"   # powrót do stadanrdowego zestawu kolorów terminala

NEWROUTER=0

# Komentarze i błędy
# ------------------------------
msg () {                        # Komentarze wyswietlane przy ustawionej opcji  -v
  if [[ ${CFG[21]} ]] ; then
    echo -e $1$2$3$4$5$6$7$8$9
  fi
}

msg2 () {                       # Komunikaty debugowania wyswietlane przy ustawionej opcji  -V
  if [[ ${CFG[22]} ]] ; then
    echo -e $1$2$3$4$5$6$7$8$9
  fi
}

err () {
#  if [[ ${CFG[22]} ]] ; then   # Ustawić prawidlowy numer $CFG[xx]
   echo -e "${R}$1${BCK}" >&2
   echo -e "${R}$2${BCK}" >&2
   echo -e "${R}$3${BCK}" >&2
#  fi
}
die () {
  status="$1"
  shift
  err "$@"
  exit "$status"
}

crt_dockerfile_qoslink() {
  rm -Rf ./dockerfiles
  mkdir ./dockerfiles
  cd ./dockerfiles
  echo "FROM centos:6.6" > dockerfile
  echo "MAINTAINER Czyz Piotr" >> dockerfile

  echo "RUN yum -y update" >> dockerfile
  echo "RUN yum -y install bridge-utils net-tools mtr tar nmap telnet wget" >> dockerfile
  
  echo "RUN wget https://iperf.fr/download/iperf_2.0.2/iperf_2.0.2-4_amd64.tar.gz \\" >> dockerfile
  echo "&& tar zxf iperf_2.0.2-4_amd64.tar.gz \\" >> dockerfile
  echo "&& cp /iperf_2.0.2-4_amd64/iperf . \\" >> dockerfile
  echo "&& rm -Rf iperf_2.0.2-4_amd64 \\" >> dockerfile
  echo "&& rm -f iperf_2.0.2-4_amd64.tar.gz" >> dockerfile
  cd ../
}

crt_dockerfile_quaggalink() {
  rm -Rf ./dockerfiles
  mkdir ./dockerfiles
  cd ./dockerfiles
  echo "FROM centos:6.6" > dockerfile
  echo "MAINTAINER Czyz Piotr" >> dockerfile

  echo "RUN yum -y update" >> dockerfile
  echo "RUN yum -y install bridge-utils net-tools mtr tar nmap telnet wget quagga" >> dockerfile
  
  echo "RUN echo \"hostname quaggalink\" > /etc/quagga/zebra.conf \\" >> dockerfile
  echo "&& echo \"hostname quaggalink\" > /etc/quagga/ripd.conf \\" >> dockerfile
  echo "&& echo \"hostname quaggalink\" > /etc/quagga/ospfd.conf \\" >> dockerfile
  echo "&& echo \"password zebra\" >> /etc/quagga/zebra.conf \\" >> dockerfile
  echo "&& echo \"password zebra\" >> /etc/quagga/ripd.conf \\" >> dockerfile
  echo "&& echo \"password zebra\" >> /etc/quagga/ospfd.conf \\" >> dockerfile
  echo "&& echo \"enable password zebra\" >> /etc/quagga/ripd.conf \\" >> dockerfile
  echo "&& echo \"enable password zebra\" >> /etc/quagga/ospfd.conf \\" >> dockerfile
  echo "&& chmod 640 /etc/quagga/zebra.conf \\" >> dockerfile
  echo "&& chmod 640 /etc/quagga/ripd.conf \\" >> dockerfile
  echo "&& chmod 640 /etc/quagga/ospfd.conf \\" >> dockerfile
  echo "&& chown quagga:quagga /etc/quagga/zebra.conf \\" >> dockerfile
  echo "&& chown quagga:quagga /etc/quagga/ripd.conf \\" >> dockerfile
  echo "&& chown quagga:quagga /etc/quagga/ospfd.conf" >> dockerfile

  echo "RUN wget https://iperf.fr/download/iperf_2.0.2/iperf_2.0.2-4_amd64.tar.gz \\" >> dockerfile
  echo "&& tar zxf iperf_2.0.2-4_amd64.tar.gz \\" >> dockerfile
  echo "&& cp /iperf_2.0.2-4_amd64/iperf . \\" >> dockerfile
  echo "&& rm -Rf iperf_2.0.2-4_amd64 \\" >> dockerfile
  echo "&& rm -f iperf_2.0.2-4_amd64.tar.gz" >> dockerfile
  cd ../
}
:
chk_crt_img_centos66() {
  LISTIMAGES=(`docker images | awk '/centos[[:space:]]*6\.6/ {print}' `)
  if [[ -z $LISTIMAGES ]] ; then
    msg "Pobieranie skompresowanego obrazu systemu CentOS 6.6"
    if [ ! -e "./centos-6-20150615_2019-docker.tar.xz" ] ; then
      wget https://github.com/CentOS/sig-cloud-instance-images/blob/311d80f2e558eba3a6ea88c387714ae2e4175702/docker/centos-6-20150615_2019-docker.tar.xz?raw=true
      mv centos-6-20150615_2019-docker.tar.xz\?raw\=true centos-6-20150615_2019-docker.tar.xz
    fi
    if [ ! -e "./Dockerfile" ] ; then
      wget https://github.com/CentOS/sig-cloud-instance-images/raw/311d80f2e558eba3a6ea88c387714ae2e4175702/docker/Dockerfile
    fi
    msg "Budowanie obrazu Centos 6.6"
    STAT=$(docker build .)
    IDCon=(`echo $STAT | grep Successfully | awk '{ print $(NF) }' `)
    docker tag $IDCon centos:6.6
    msg "Utworzono obraz centos:6.6 "
  fi
}

# Sprawdzanie dostępności obrazu qoslink w repozytorium lokalnym / ew. utworzenie
chk_crt_img_qoslink() {
  LISTIMAGES=(`docker images | awk '/chefronpc\/qoslink/ {print}' `)
  if [[ -z $LISTIMAGES ]] ; then
    # Sprawdzenie dostępności obrazu qoslink w repo Docker
    LISTIMAGES=(`docker search qoslink | awk '/chefronpc\/qoslink/ {print}' `)
    if [[ -z $LISTIMAGES ]] ; then
      # Sprawdzenie dostęności obrazu Centos 6.6 i ewentualne utworzenie
      chk_crt_img_centos66 
      # Tworzenie pliku dockerfile dla konfiguracji kontenera Qoslink
      crt_dockerfile_qoslink
      STAT=$(docker build ./dockerfiles/)
      IDCon=(`echo $STAT | grep Successfully | awk '{ print $(NF) }' `)
      docker tag $IDCon chefronpc/qoslink:v1
      msg "Utworzono kontener qoslink"
    else
      # Pobranie obrazu qoslink ze zdalnego repo Dokcer'a
      docker pull chefronpc/qoslink:v1
    fi
  fi
}

# Sprawdzanie dostępności obrazu quaggalink w repozytorium lokalnym / ew. utworzenie
chk_crt_img_quaggalink() {
  LISTIMAGES=(`docker images | awk '/chefronpc\/quaggalink/ {print}' `)
  if [[ -z $LISTIMAGES ]] ; then
    # Sprawdzenie dostępności obrazu quaggalink w repo Docker
    LISTIMAGES=(`docker search quaggalink | awk '/chefronpc\/quaggalink/ {print}' `)
    if [[ -z $LISTIMAGES ]] ; then
      # Sprawdzenie dostęności obrazu Centos 6.6 i ewentualne utworzenie
      chk_crt_img_centos66 
      # Tworzenie pliku dockerfile dla konfiguracji kontenera Quaggalink
      crt_dockerfile_quaggalink
      STAT=$(docker build ./dockerfiles/)
      IDCon=(`echo $STAT | grep Successfully | awk '{ print $(NF) }' `)
      docker tag $IDCon chefronpc/quaggalink:v1
      msg "Utworzono kontener quaggalink"
    else
      # Pobranie obrazu quaggalink ze zdalnego repo Dokcer'a
      docker pull chefronpc/quaggalink:v1
    fi
  fi
}

chk_img_qoslink() {
: # :
}


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
    if [[ "$BRPREFIX$CNT" = "${CFG[7]}" || "$BRPREFIX$CNT" = "${CFG[8]}" ]] ; then
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

# Sprawdza dostępność switcha
# We - $1 nazwa switcha
# --------------------------
checkswitch() {
  LISTSWITCH=(`nmcli d | awk '{ print $1 }'`)
  for (( CNT=0; CNT<${#LISTSWITCH[@]}; CNT++ )) ; do
    if [[ "$1" = "${LISTSWITCH[$CNT]}" ]] ; then
      return 0
    fi
  done
  return 1
}

# Zwraca numer pierwszego wolnego switcha
# Wy - nazwa switcha
# ------------------------------
freeswitch() {
  LISTSWITCH=(`nmcli d | grep $SWPREFIX[[:digit:]] | awk '{ print $1 }' | sort`)
  for (( CNT=0; CNT<$SWMAX; CNT++ )) ; do
    PASS=0
    if [[ "$SWPREFIX$CNT" = "${CFG[16]}" || "$SWPREFIX$CNT" = "${CFG[17]}" ]] ; then
      PASS=1
    fi
    ANS=(`echo ${LISTSWITCH[@]} | grep $SWPREFIX$CNT `)
    if [[ -n ${ANS[@]} ]] ; then 
      PASS=1
    fi
    if [[ $PASS -eq 0 ]] ; then 
      SWNAME=$SWPREFIX$CNT		# Wyszukana wolna nazwa dla nowego switcha
      return 0
    fi
  done
  die 6 "Brak wolnych switch'y"
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
  for (( CNT=1; CNT<$IFMAX; CNT++ )) ; do
    PASS=0 
    for (( CNT2=1; CNT2<${#LISTINTERFACE[@]}; CNT2++ )) ; do
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
    msg2 "${Y}Parse IP - poprawne${BCK}"
    return 0		# IP/mask poprawne
  else
    msg2 "${Y}Parse IP - niepoprawne${BCK}"
    return 1		# IP/mask błędne
  fi
}


# We - $1 IP/Netmask  format:  x.y.z.v/mm 
# We - $2 IP/Netmask
# We - $3 1 Widoczność komunikatów,    0 - brak
# ----------------------------
comparenet() {
  msg2 "${Y}Porównanie dwóch adresów sieci  ($1) i ($2) ${BCK}"
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
          msg "${RED}Konflikt adresów IP:  $1${BCK}"
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
        msg "${R}Adresy sieci $1 $2 niezgodne${BCK}"
      fi
      return
    fi
  else
    NET=1			# Różne długości maski
    if [[ "$3" -eq "1" ]] ; then 
      msg "${R}Różne długości maski w adresach $1 $2${BCK}"
    fi
    return
  fi
  die 20 "Bład w funkcji comparenet()"
}


# Sprawdza dostępnosc parametrów sieci we wszystkich kontenerze
# We - $1 IP/Netmask
# ------------------------------------
checkipall() {
  msg "Weryfikacja adresu IP $1 we wszystkich kontenerach" 
  if parseip "$1" ; then
    # Sprawdza czy IP jest adresem sieci czy broadcastem 
    comparenet "$1" "0.0.0.0"
    if [[ "${NET1[0]}.${NET1[1]}.${NET1[2]}.${NET1[3]}/$M1" == "$1" ]] ; then
      die 25 "Adres IP $1 nie może byc adresem sieci."
    fi
    if [[ "${BROADCAST1[0]}.${BROADCAST1[1]}.${BROADCAST1[2]}.${BROADCAST1[3]}/$M1" == "$1" ]] ; then
      die 26 "Adres IP $1 nie może być adresem broadcast."
    fi

    STAT=1				# Domyslnie IP jest poza adresacja sieci w testowanym kontenerze
    LISTCONTAINER=(`docker ps | sed -n -e '1!p' | awk '{ print $(NF) }' `)
    for (( CNT2=0; CNT2<${#LISTCONTAINER[@]}; CNT2++ )) ; do
      msg2 "="  # rem
      msg2 "============= ${Y} kontener  ${LISTCONTAINER[$CNT2]} ${BCK} ===================" # rem
      LISTIP=(`docker exec ${LISTCONTAINER[$CNT2]} ip a | awk '/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\// {print $2,$(NF)}' `)
      let LISTIPMAX=${#LISTIP[@]}
      for (( CNT=0; CNT<$LISTIPMAX; CNT=$CNT+2 )) ; do
  
     #   if [[ "$1" = "${LISTIP[$CNT]}" ]] ; then
     #     die 15 "Konflikt adresów IP $1 w kontenerze ${LISTCONTAINER[$CNT2]}"
     #     return 		# Podane IP jest w konflikcie z IP w danym kontenerze
     #   fi
        comparenet "$1" "${LISTIP[$CNT]}"
        case "$NET" in
          "3")
            msg2 "check case - podsieci zgodne - bez konfliktu"
            if [[ "$STAT" -lt "4" ]] ; then 
              STAT=3
            fi ;;
          "2")
            msg2 "check case - podsieci rózne"
            if [[ "$STAT" -lt "3" ]] ; then
              STAT=2
            fi ;;
          "1")
            msg2 "check case - rozne dlugosci maski"
            if [[ "$STAT" -lt "2" ]] ; then
              STAT=1
            fi ;;
          "0")
            msg2 "check case - konflikt adresow"
             tmp=$1; tmp2=${LISTCONTAINER[$CNT2]}
             msg "${R}Wykryto konflikt adresów ...${BCK}"
             freeip $1
             die 15 "Konflikt adresów IP $tmp w kontenerze $tmp2." "${BCK}Pierwszy wolny adres w sieci ${NET1[0]}.${NET1[1]}.${NET1[2]}.${NET1[3]}/$M1 to: ${G}$NEWIP${BCK}"
            ;;
        esac
      done
    done
    msg "Brak konfliku dla adresu ${G}$1${BCK}"
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
  NEWGW="${BROADCAST1[0]}.${BROADCAST1[1]}.${BROADCAST1[2]}.$[BROADCAST1[3]-1]/$M1"
  msg2 " -----------------------------------" # rem
  msg2 " ${Y}WOLNY ADRES IP:  $NEWIP ${BCK}" # rem
  msg2 " -----------------------------------" # rem
  msg "Rezerwacja adresu IP: ${G}$NEWIP${BCK}"
  msg "Adres domyślny gateway: $NEWGW"
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
      msg2 "LISTA: ${LISTIM[@]}"
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
  msg2 " ${Y}Wolny adres sieci IP: $NEWNET${BCK}"
  msg2 " -----------------------------------" # rem
  msg "Rezerwacja adresu sieci: ${G}$NEWNET${BCK}"
 return 0
}



# ---- Przypisanie nazwy dla kontenera <c>
set_c() {
if [[ -z ${CFG[0]} ]] ; then
  if freecontainer ; then 
    CFG[0]=$QOSNAME
    msg "Przypisano nazwę kontenera -c: <${G}${CFG[0]}${BCK}>"
  fi
fi
return 0
}

# ---- Przypisanie nazwy dla routera Quagga <r1>
set_r1() {
if [[ "${CFG[18]}" == "setnamecntquagga" ]] ; then
  if freerouter ; then 
    CFG[18]=$QUAGGANAME
    msg "Przypisano nazwę routera w kontenerze -r1: <${G}${CFG[18]}${BCK}>"
  fi
fi
return 0
}

# ---- Przypisanie nazwy dla routera Quagga <r2>
set_r2() {
if [[ "${CFG[19]}" == "setnamecntquagga" ]] ; then
  if freerouter ; then 
    CFG[19]=$QUAGGANAME
    msg "Przypisano nazwę routera w kontenerze -r2: <${G}${CFG[19]}${BCK}>"
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

# -----  Przypisanie nazwy dla switcha <sw1>  -------
set_sw1() {
if [[ "${CFG[16]}" == "setnamebrswitch" ]] ; then
  if freeswitch ; then 
    CFG[16]=$SWNAME
    msg "Przypisano nazwę switcha -sw1: <${G}${CFG[16]}${BCK}>"
  fi
fi
return 0
}

# -----  Przypisanie nazwy dla switch <sw2>  -------
set_sw2() {
if [[ "${CFG[17]}" == "setnamebrswitch" ]] ; then
  if freeswitch ; then 
    CFG[17]=$SWNAME
    msg "Przypisano nazwę switcha -sw2: <${G}${CFG[17]}${BCK}>"
  fi
fi
return 0
}

# -----  Przypisanie nazwy dla interfejsu <if1> w hoscie <-h1>  -------
set_if1() {
if [[ -z ${CFG[3]} ]] ; then
  if freeinterface "${CFG[1]}" ; then
    CFG[3]=$IFNAME
    msg "Przypisano nazwę interfejsu -if1: <${G}${CFG[3]}${BCK}> dla ip:<${G}${CFG[5]}${BCK}> w kontenerze <${G}${CFG[1]}${BCK}>"
  fi
fi
return 0
}

# -----  Przypisanie nazwy dla interfejsu <if2> w hoscie <-h2>  -------
set_if2() {
if [[ -z ${CFG[4]} ]] ; then
  if freeinterface "${CFG[2]}" ; then
    CFG[4]=$IFNAME
    msg "Przypisano nazwę interfejsu -if2: <${G}${CFG[4]}${BCK}> ip:<${G}${CFG[6]}${BCK}> w kontenerze <${G}${CFG[2]}${BCK}>"
  fi
fi
return 0
}

# -----  Przypisanie nazwy dla interfejsu <if1> w routerze <-r1>  -------
set_if1r1() {
if [[ -z ${CFG[3]} ]] ; then
  if freeinterface "${CFG[18]}" ; then
    CFG[3]=$IFNAME
    msg "Przypisano nazwę interfejsu -if1: <${G}${CFG[3]}${BCK}> ip:<${G}${CFG[5]}${BCK}> w kontenerze <${G}${CFG[18]}${BCK}>"
  fi
fi
return 0
}

# -----  Przypisanie nazwy dla interfejsu <if2> w routerze <-r2>  -------
set_if2r2() {
if [[ -z ${CFG[4]} ]] ; then
  if freeinterface "${CFG[19]}" ; then
    CFG[4]=$IFNAME
    msg "Przypisano nazwę interfejsu -if2: <${G}${CFG[4]}${BCK}> ip:<${G}${CFG[6]}${BCK}> w kontenerze <${G}${CFG[19]}${BCK}>"
  fi
fi
return 0
}

# -----  Przypisanie nazwy dla interfejsu <if3> w kontenerze linku <-c>  -------
set_if3() {
if [[ -z ${CFG[25]} ]] ; then
  if freeinterface "${CFG[0]}" ; then
    CFG[25]=$IFNAME
    msg "Przypisano nazwę interfejsu -if3: <${G}${CFG[25]}${BCK}> ip:<${G}${CFG[23]}${BCK}> w kontenerze <${G}${CFG[0]}${BCK}>"
  fi
fi
return 0
}

# -----  Przypisanie nazwy dla interfejsu <if4> w kontenerze linku <-c>  -------
set_if4() {
if [[ -z ${CFG[26]} ]] ; then
  if freeinterface "${CFG[0]}" ; then
    CFG[26]=$IFNAME
    msg "Przypisano nazwę interfejsu -if4: <${G}${CFG[26]}${BCK}> ip:<${G}${CFG[24]}${BCK}> w kontenerze <${G}${CFG[0]}${BCK}>"
  fi
fi
return 0
}

# -----  Uruchomienie kontenera łączącego hosty ( QoSLink )
crt_c() {
  ANS=(` docker run -d -ti --name ${CFG[0]} --hostname ${CFG[0]} --net none --cap-add All chefronpc/qoslink:v1 /bin/bash `)
  msg "Uruchomienie kontenera łączącego ${CFG[0]}"
}

# -----  Uruchomienie kontenera -r1 - Router Quagga ( QoSQuagga )
crt_r1() {
  if ! checkrouter "${CFG[18]}" ; then
    ANS=(` docker run -d -ti --name ${CFG[18]} --hostname ${CFG[18]} --net none --cap-add ALL chefronpc/quaggalink:v1 /bin/bash `) 
    ANS=(` docker exec ${CFG[18]} /bin/bash -c 'service zebra start && service ospfd start' `)
    ANS=(` docker exec ${CFG[18]} /bin/bash -c 'vtysh -e "configure terminal" -e "log file /var/log/quagga/quagga.log" -e "exit" -e "write" ' `)
    msg "Uruchomienie routera Quagga w kontenerze ${CFG[18]}"
    NEWROUTER="new"	# znacznik nowego routera - wymagany przy tworzeniu ID-Routera
    return		# jeżeli nowy -> tworzy ID-Routera wg nr IP
  fi
  msg "Router Quagga w kontenerze ${Y}${CFG[18]} jest już w systemie${BCK}"
  msg "Skonfigurowany zostanie ${Y}dodatkowy interfejs w ${CFG[18]}${BCK} z adresem ${Y}${CFG[5]}${BCK}"
  NEWROUTER="old"	# Jeżeli już był uruchomiony -> pozostawia istniejący ID-routera
}

# -----  Uruchomienie kontenera -r2 - Router Quagga ( QoSQuagga )
crt_r2() {
  if ! checkrouter "${CFG[19]}" ; then
    ANS=(` docker run -d -ti --name ${CFG[19]} --hostname ${CFG[19]} --net none --cap-add ALL chefronpc/quaggalink:v1 /bin/bash `)
    ANS=(` docker exec ${CFG[19]} /bin/bash -c 'service zebra start && service ospfd start' `)
    ANS=(` docker exec ${CFG[19]} /bin/bash -c 'vtysh -e "configure terminal" -e "log file /var/log/quagga/quagga.log" -e "exit" -e "write" ' `)
    msg "Uruchomienie routera Quagga w kontenerze ${CFG[19]}"
    NEWROUTER=0		# znacznik nowego routera - wymagany przy tworzeniu ID-Routera
    return		# jeżeli nowy -> tworzy ID-Routera wg nr IP
  fi
  msg "Router Quagga w kontenerze ${Y}${CFG[19]} jest już w systemie${BCK}"
  msg "Skonfigurowany zostanie ${Y}dodatkowy interfejs w ${CFG[19]}${BCK} z adresem ${Y}${CFG[6]}${BCK}"
  NEWROUTER=1		# Jeżeli już był uruchomiony -> pozostawia istniejący ID-routera
}


# -----  Tworzenie połączen pomiędzy bridgem a kontenerem
crt_linkif1() {
  pipework ${CFG[7]} -i ${CFG[3]} ${CFG[1]} ${CFG[5]}
  if [[ -n ${CFG[30]} ]] ; then
    if [[ "${CFG[30]}" == "setgw" ]] ; then
      BCAST1=(` ipcalc ${CFG[5]} -b | awk -F= '{print $2}' | awk -F. '{print $1,$2,$3,$4}' `)
      CFG[30]="${BCAST1[0]}.${BCAST1[1]}.${BCAST1[2]}.$[BCAST1[3]-1]"
    fi
    docker exec ${CFG[1]} ip route add default via ${CFG[30]}
    msg "Polaczenie bridg'a -br1 ${CFG[7]} z hostem ${CFG[1]} gateway:${CFG[30]}"
  else  
    msg "Polaczenie bridg'a -br1 ${CFG[7]} z hostem ${CFG[1]}"
  fi
}

crt_linkif2() {
  pipework ${CFG[8]} -i ${CFG[4]} ${CFG[2]} ${CFG[6]}
  if [[ -n ${CFG[31]} ]] ; then
    if [[ "${CFG[31]}" == "setgw" ]] ; then
      BCAST1=(` ipcalc ${CFG[6]} -b | awk -F= '{print $2}' | awk -F. '{print $1,$2,$3,$4}' `)
      CFG[31]="${BCAST1[0]}.${BCAST1[1]}.${BCAST1[2]}.$[BCAST1[3]-1]"
    fi
    docker exec ${CFG[2]} ip route add default via ${CFG[31]}
    msg "Polaczenie bridg'a -br1 ${CFG[8]} z hostem ${CFG[2]} gateway:${CFG[31]}"
  else  
    msg "Polaczenie bridg'a -br1 ${CFG[8]} z hostem ${CFG[2]}"
  fi  
}

crt_linkif3() {
  pipework ${CFG[7]} -i ${CFG[25]} ${CFG[0]} ${CFG[23]}
  msg "Polaczenie bridg'a -br1 ${CFG[7]} z kontenerem ${CFG[0]}"
}

crt_linkif4() {
  pipework ${CFG[8]} -i ${CFG[26]} ${CFG[0]} ${CFG[24]}
  msg "Polaczenie bridg'a -br1 ${CFG[8]} z kontenerem ${CFG[0]}"
}

crt_linkif1r1() {
  pipework ${CFG[7]} -i ${CFG[3]} ${CFG[18]} ${CFG[5]}
  msg "Polaczenie bridg'a -br1 ${CFG[7]} z routerem ${CFG[18]}"
  # Konfiguracja daemona ZEBRA w routerze
  ANS=(`docker exec ${CFG[18]} vtysh -c "configure terminal" -c "interface ${CFG[3]}" -c "ip address ${CFG[5]}" -c "description to-${CFG[0]}" -c "ip ospf hello-interval 2" -c "ip ospf dead-interval 5" -c "no shutdown" -c "exit" -c "exit" -c "write" `)
  # Odczytanie adresu sieci na podstawie IP i Maski
  NET1=(` ipcalc ${CFG[5]} -n | awk -F= '{print $2}' | awk -F. '{print $1,$2,$3,$4}' `)
  NETM[3]=${NET1[3]}; NETM[2]=${NET1[2]}; NETM[1]=${NET1[1]}; NETM[0]=${NET1[0]} # Adres sieci
  NEWNET="${NETM[0]}.${NETM[1]}.${NETM[2]}.${NETM[3]}/$M1"
  # Utworzenie ID routera na podstawie adresu IP - gwarancja niepowtarzalności
  ID=(`echo ${CFG[5]} | awk -F'/' '{print $1}' `)
  # Konfiguracja daemona OSPF w routerze
  if [[ "$NEWROUTER" = "new" ]] ; then
    ANS=(` docker exec ${CFG[18]} vtysh -c "configure terminal" -c "router ospf" -c "router-id $ID" -c "network $NEWNET area 0" -c "exit" -c "exit" -c "write" `)
    echo "New router"
  else
    ANS=(` docker exec ${CFG[18]} vtysh -c "configure terminal" -c "router ospf" -c "network $NEWNET area 0" -c "exit" -c "exit" -c "write" `)
    echo "Add interface to router"
  fi
  msg "Konfiguracja daemona ZEBRA oraz OSPF w routerze ${CFG[18]}"
}

crt_linkif2r2() {
  pipework ${CFG[8]} -i ${CFG[4]} ${CFG[19]} ${CFG[6]}
  msg "Polaczenie bridg'a -br1 ${CFG[8]} z routerem ${CFG[19]}"
  # Konfiguracja daemona ZEBRA w routerze
  ANS=(` docker exec ${CFG[19]} vtysh -c "configure terminal" -c "interface ${CFG[4]}" -c "ip address ${CFG[6]}" -c "description to-${CFG[0]}" -c "ip ospf hello-interval 2" -c "ip ospf dead-interval 5" -c "no shutdown" -c "exit" -c "exit" -c "write" `)
  # Odczytanie adresu sieci na podstawie IP i Maski
  NET1=(` ipcalc ${CFG[6]} -n | awk -F= '{print $2}' | awk -F. '{print $1,$2,$3,$4}' `)
  NETM[3]=${NET1[3]}; NETM[2]=${NET1[2]}; NETM[1]=${NET1[1]}; NETM[0]=${NET1[0]} # Adres sieci
  NEWNET="${NETM[0]}.${NETM[1]}.${NETM[2]}.${NETM[3]}/$M1"
  # Utworzenie ID routera na podstawie adresu IP - gwarancja niepowtarzalności
  ID=(`echo ${CFG[6]} | awk -F'/' '{print $1}' `)
  # Konfiguracja daemona OSPF w routerze
  if [[ "$NEWROUTER" = "new" ]] ; then
    ANS=(` docker exec ${CFG[19]} vtysh -c "configure terminal" -c "router ospf" -c "router-id $ID" -c "network $NEWNET area 0" -c "exit" -c "exit" -c "write" `)
    echo "New router"
  else
    ANS=(` docker exec ${CFG[19]} vtysh -c "configure terminal" -c "router ospf" -c "network $NEWNET area 0" -c "exit" -c "exit" -c "write" `)
    echo "Add interface to router"
  fi
  msg "Konfiguracja daemona ZEBRA oraz OSPF w routerze ${CFG[19]}"
}

crt_linkif3sw1() {
  pipework ${CFG[16]} -i ${CFG[25]} ${CFG[0]} ${CFG[23]}
  msg "Polaczenie switch'a -sw1 ${CFG[16]} z kontenerem ${CFG[0]}"
}

crt_linkif4sw2() {
  pipework ${CFG[17]} -i ${CFG[26]} ${CFG[0]} ${CFG[24]}
  msg "Polaczenie switch'a -sw1 ${CFG[17]} z kontenerem ${CFG[0]}"
}


# ----  Utworzenie bridga br0 wewnątrz kontenera <qoslinkxx>
# ----  umożliwia przekazywanie pakietów poprzez kontener <qoslinkxx>
# ----  z zachowaniem zadanych parametrów transmisji
crt_brinqos() {
  msg "Utworzenie bridga br0 w kontenerze ${CFG[0]} mostkujący interfejsy ${CFG[25]} oraz ${CFG[26]}"
  msg "Adres ip ${G}${CFG[0]}${BCK} to ${G}${CFG[23]}${BCK}.  Adres ip ${G}${CFG[24]}${BCK} zostaje ${G}wolny${BCK}."
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
  msg "Kofiguracja parametrów łącza:"
  msg "Pasmo ${G}${CFG[9]}/${CFG[10]}${BCK} z opóżnieniem ${G}${CFG[13]}/${CFG[14]}${BCK}"
  msg "Utrata pakietów ${G}${CFG[11]}/${CFG[12]}${BCK}  duplikowanie ${G}${CFG[28]}/${CFG[29]}${BCK}"
  msg "Sumaryczne:  Pasmo ${G}${CFG[34]}${BCK}  opóźnienie ${G}${CFG[36]}${BCK} utrata pakietów ${G}${CFG[35]}${BCK} duplikowanie ${G}${CFG[37]}${BCK}"

  ANS=(`docker exec ${CFG[0]} tc qdisc add dev ${CFG[25]} root handle 1:0 tbf rate ${CFG[9]} latency 100ms burst 50k`)
  ANS=(`docker exec ${CFG[0]} tc qdisc add dev ${CFG[26]} root handle 1:0 tbf rate ${CFG[10]} latency 100ms burst 50k`)
  ANS=(`docker exec ${CFG[0]} tc qdisc add dev ${CFG[25]} parent 1:1 handle 10:0 netem delay ${CFG[13]} loss ${CFG[11]} duplicate ${CFG[28]} `)
  ANS=(`docker exec ${CFG[0]} tc qdisc add dev ${CFG[26]} parent 1:1 handle 10:0 netem delay ${CFG[14]} loss ${CFG[12]} duplicate ${CFG[29]} `)

  BUF=""
  for (( CNT=0; CNT<${#WSK[@]}; CNT++ )) ; do
    if [[ -z ${CFG[$CNT]} ]] ; then
      BUF=${BUF}:_
    else
      BUF=${BUF}:${CFG[$CNT]}
    fi
  done
  echo $BUF > buffor_cfg.dat
  docker cp buffor_cfg.dat ${CFG[0]}:/buffor_cfg.dat
}


upgrade_link() {
  rm -f buffor_cfg.dat
  docker cp ${CFG[0]}:/buffor_cfg.dat buffor_cfg.dat
  CFG2=(` awk 'BEGIN { RS = ":" } ; { print $0 }' buffor_cfg.dat `)
  for (( CNT=0; CNT<${#WSK[@]}; CNT++ )) ; do
    if [[ ${CFG2[$CNT]} == "_" ]] ; then
      CFG2[$CNT]=""
    fi
#    echo "CFG2[$CNT]=${CFG2[$CNT]}"
  done
  if [[ -n ${CFG[9]} ]] ; then
    CFG2[9]=${CFG[9]}
  fi
  if [[ -n ${CFG[10]} ]] ; then
    CFG2[10]=${CFG[10]}
  fi
  if [[ -n ${CFG[11]} ]] ; then
    CFG2[11]=${CFG[11]}
  fi
  if [[ -n ${CFG[12]} ]] ; then
    CFG2[12]=${CFG[12]}
  fi
  if [[ -n ${CFG[13]} ]] ; then
    CFG2[13]=${CFG[13]}
  fi
  if [[ -n ${CFG[14]} ]] ; then
    CFG2[14]=${CFG[14]}
  fi
  if [[ -n ${CFG[28]} ]] ; then
    CFG2[28]=${CFG[28]}
  fi
  if [[ -n ${CFG[29]} ]] ; then
    CFG2[29]=${CFG[29]}
  fi
  if [[ -n ${CFG[34]} ]] ; then
    CFG2[34]=${CFG[34]}
  else
    CFG2[34]=""
  fi
  if [[ -n ${CFG[35]} ]] ; then
    CFG2[35]=${CFG[35]}
  else
    CFG2[35]=""
  fi
  if [[ -n ${CFG[36]} ]] ; then
    CFG2[36]=${CFG[36]}
  else
    CFG2[36]=""
  fi
  if [[ -n ${CFG[37]} ]] ; then
    CFG2[37]=${CFG[37]}
  else
    CFG2[37]=""
  fi

  msg "Zmiana parametrów łącza:"
  msg "Pasmo ${G}${CFG2[9]}/${CFG2[10]}${BCK} z opóżnieniem ${G}${CFG2[13]}/${CFG2[14]}${BCK}"
  msg "Utrata pakietów ${G}${CFG2[11]}/${CFG2[12]}${BCK}  duplikowanie ${G}${CFG2[28]}/${CFG2[29]}${BCK}"
  msg "Sumaryczne: Pasmo ${G}${CFG2[34]}${BCK}  opóźnienie ${G}${CFG2[36]}${BCK} utrata pakietów ${G}${CFG2[35]}${BCK} duplikowanie ${G}${CFG2[37]}${BCK}"
  ANS=(`docker exec ${CFG2[0]} tc qdisc change dev ${CFG2[25]} root handle 1:0 tbf rate ${CFG2[9]} latency 100ms burst 50k`)
  ANS=(`docker exec ${CFG2[0]} tc qdisc change dev ${CFG2[26]} root handle 1:0 tbf rate ${CFG2[10]} latency 100ms burst 50k`)
  ANS=(`docker exec ${CFG2[0]} tc qdisc change dev ${CFG2[25]} parent 1:1 handle 10:0 netem delay ${CFG2[13]} loss ${CFG2[11]} duplicate ${CFG2[28]} `)
  ANS=(`docker exec ${CFG2[0]} tc qdisc change dev ${CFG2[26]} parent 1:1 handle 10:0 netem delay ${CFG2[14]} loss ${CFG2[12]} duplicate ${CFG2[29]} `)

  BUF=""
  for (( CNT=0; CNT<${#WSK[@]}; CNT++ )) ; do
    if [[ -z ${CFG2[$CNT]} ]] ; then
      BUF=${BUF}:_
    else
      BUF=${BUF}:${CFG2[$CNT]}
    fi
  done
  echo $BUF > buffor_cfg.dat
  docker cp buffor_cfg.dat ${CFG[0]}:/buffor_cfg.dat
return
}

# Sprawdzenie poprawności parametru -band
# We -  -band
# Wy -  Zmienne ANS1 i ANS2
# ---------------------------------------
chk_band() {
  ANS1=(`echo ${CFG[$1]} | grep -E "^([1-9][0-9][0-9]*|[1-9][0-9]|[0-9])(\.[0-9][0-9]*)?[MmKk]bit$"`)
  ANS2=(`echo ${CFG[$1]} | grep -E "^([1-9][0-9][0-9]*|[1-9][0-9]|[0-9])bit$"`)
  if ! [[ -n $ANS1 || -n $ANS2 ]] ; then
    die 60 "Niepoprawny format parametru ${WSK[$1]}"
  fi
  return
}

# Sprawdzenie poprawności parametru -loss
# We -  -loss
# Wy -  Zmienne ANS1 i ANS2
#----------------------------------------
chk_loss() {
  ANS1=(`echo ${CFG[$1]} | grep -E "^(100|[1-9][0-9]|[0-9])(\.[0-9][0-9]*)?%$"`)
  ANS2=(`echo ${CFG[$1]} | grep -E "^([1-9][0-9][0-9]*|[1-9][0-9]|[0-9])$"`)
  if ! [[ -n $ANS1 || -n $ANS2 ]] ; then
    die 60 "Niepoprawny format parametru ${WSK[$1]}"
  fi
  return
}

# Sprawdzenie poprawności parametru -delay
# We -  -delay
# Wy -  Zmienna ANS1
#----------------------------------------
chk_delay() {
  ANS1=(`echo ${CFG[$1]} | grep -E "^([1-9][0-9][0-9]*|[1-9][0-9]|[0-9])(\.[0-9][0-9]*)?ms$"`)
  ANS2=(`echo ${CFG[$1]} | grep -E "^([1-9][0-9][0-9]*|[1-9][0-9]|[0-9])ms$"`)
  if ! [[ -n $ANS1 || -n $ANS2 ]] ; then
    die 60 "Niepoprawny format parametru ${WSK[$1]}"
  fi
  return
}

# Sprawdzenie poprawności parametru -duplic
# e -  -duplic
# Wy -  Zmienne ANS1 i ANS2
#----------------------------------------
chk_duplic() {
  ANS1=(`echo ${CFG[$1]} | grep -E "^(100|[1-9][0-9]|[0-9])(\.[0-9][0-9]*)?%$"`)
  ANS2=(`echo ${CFG[$1]} | grep -E "^([1-9][0-9][0-9]*|[1-9][0-9]|[0-9])$"`)
  if ! [[ -n $ANS1 || -n $ANS2 ]] ; then
    die 60 "Niepoprawny format parametru ${WSK[$1]}"
  fi
  return
}

del_container() {
  if [[ "${CFG[27]}" = "deldefaultnamecnt" ]] ; then
   : # :
  fi
}

# Lista typów łączy
# ------------------
LINK=(10Base 100Base ADSL3/8 ISDN SDI)  

#  Konfiguruje komplet parametrów łącza
#  -band -loss -delay -duplic
#  według podanego typu z listy
# We - $1 Parametr -link $CFG[15]
# -------------------------------------
checklink() {
case "$1" in
  "10Base")
    CFG[9]=10Mbit   ; CFG[10]=10Mbit
    CFG[11]=0%      ; CFG[12]=0%
    CFG[13]=0.3ms   ; CFG[14]=0.3ms
    CFG[28]=0.001%  ; CFG[29]=0.001% 
    ;;
  "100Base")
    CFG[9]=100Mbit  ; CFG[10]=100Mbit
    CFG[11]=0%      ; CFG[12]=0%
    CFG[13]=0.2ms   ; CFG[14]=0.2ms
    CFG[28]=0.002%  ; CFG[29]=0.002%
    ;;
  "ADSL3/8")
    CFG[9]=3Mbit    ; CFG[10]=8Mbit
    CFG[11]=0.08%   ; CFG[12]=0.08%
    CFG[13]=2.4ms   ; CFG[14]=2.4ms
    CFG[28]=0.01%   ; CFG[29]=0.01%
    ;;
  "ISDNBRI")
    CFG[9]=128kbit  ; CFG[10]=128kbit
    CFG[11]=0.02%   ; CFG[12]=0.02%
    CFG[13]=2ms     ; CFG[14]=2ms
    CFG[28]=0.01%   ; CFG[29]=0.01%
    ;;
  "SDI")
    CFG[9]=115kbit  ; CFG[10]=115kbit
    CFG[11]=0.3%    ; CFG[12]=0.3%
    CFG[13]=2ms     ; CFG[14]=2ms
    CFG[28]=0.2%    ; CFG[29]=0.2%
    ;;
  "802.11b")
    CFG[9]=6Mbit    ; CFG[10]=6Mbit
    CFG[11]=1.7%    ; CFG[12]=1.7%
    CFG[13]=0.9ms   ; CFG[14]=0.9ms
    CFG[28]=0.2%    ; CFG[29]=0.2%
    ;;
  "802.11a")
    CFG[9]=25Mbit   ; CFG[10]=25Mbit
    CFG[11]=2%      ; CFG[12]=2%
    CFG[13]=0.6ms   ; CFG[14]=0.6ms
    CFG[28]=0.3%    ; CFG[29]=0.3%
    ;;
  "802.11g")
    CFG[9]=25Mbit   ; CFG[10]=25Mbit
    CFG[11]=1.2%    ; CFG[12]=1.2%
    CFG[13]=0.9ms   ; CFG[14]=0.9ms
    CFG[28]=0.5%    ; CFG[29]=0.5%
    ;;
  "802.11n")
    CFG[9]=65Mbit   ; CFG[10]=65Mbit
    CFG[11]=1.2%    ; CFG[12]=1.2%
    CFG[13]=0.9ms   ; CFG[14]=0.9ms
    CFG[28]=0.5%    ; CFG[29]=0.5%
    ;;
  *) die 58 "Nieprawdłowy parametr -link"
     return 1
esac
return 0
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
#   Tablica z dostępnymi opcjami oraz parametrami wejściowymi dla skryptu
#   | 0 | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9    | 10   | 11   | 12   | 13    | 14    | 15  | 16 | 17 | 18 | 19 | 20 | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28     | 29     | 30 | 31 | 32 | 33 | 34  | 35  | 36   | 37 )
WSK=(-c  -h1  -h2  -if1 -if2 -ip1 -ip2 -br1 -br2 -band1 -band2 -loss1 -loss2 -delay1 -delay2 -link -sw1 -sw2 -r1  -r2  -U   -v   -V   -ip3 -ip4 -if3 -if4 -D   -duplic1 -duplic2 -gw1 -gw2 -ph1 -ph2 -band -loss -delay -duplic)

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
      CFGNEXT=${CFG[$CNT2]}		# Pierwszy znak następnego parametru 
      CFGNEXT=${CFGNEXT:0:1}		# "-" lub pusty ciąg oznacza brak argumentu 
					# w bieżacym parametrze (np. -sw1 -h2 serwer

      if [ ${PARAM[$CNT]} = "-r1" ] ; then		# Wtymusza automatyczną nazwę routera
        if [[ -n ${CFG[$CNT2]} ]] ; then
          if [[ "$CFGNEXT" = "-" ]] ; then
            CFG[$CNT2]="setnamecntquagga"
          fi
        else
          CFG[$CNT2]="setnamecntquagga"
        fi
      fi

      if [ ${PARAM[$CNT]} = "-r2" ] ; then		# Wymusza  automatyczną nazwę routera
        if [[ -n ${CFG[$CNT2]} ]] ; then
          if [[ "$CFGNEXT" = "-" ]] ; then
            CFG[$CNT2]="setnamecntquagga"
          fi
        else
          CFG[$CNT2]="setnamecntquagga"
        fi
      fi

      if [ ${PARAM[$CNT]} = "-sw1" ] ; then 
        if [[ -n ${CFG[$CNT2]} ]] ; then              # Wymusza automatyczną nazwę switcha
          if [[ "$CFGNEXT" = "-" ]] ; then
            CFG[$CNT2]="setnamebrswitch"
          fi
        else
          CFG[$CNT2]="setnamebrswitch"
        fi
      fi

      if [ ${PARAM[$CNT]} = "-sw2" ] ; then 
        if [[ -n ${CFG[$CNT2]} ]] ; then              # Wymusza automatyczną nazwę switcha
          if [[ "$CFGNEXT" = "-" ]] ; then
            CFG[$CNT2]="setnamebrswitch"
          fi
        else
          CFG[$CNT2]="setnamebrswitch"
        fi
      fi

      if [ ${PARAM[$CNT]} = "-gw1" ] ; then 
        if [[ -n ${CFG[$CNT2]} ]] ; then              # Wymusza automatyczny adres gateway
          if [[ "$CFGNEXT" = "-" ]] ; then
            CFG[$CNT2]="setgw"
          fi
        else
          CFG[$CNT2]="setgw"
        fi
      fi

      if [ ${PARAM[$CNT]} = "-gw2" ] ; then 
        if [[ -n ${CFG[$CNT2]} ]] ; then              # Wymusza automatyczny adres gateway
          if [[ "$CFGNEXT" = "-" ]] ; then
            CFG[$CNT2]="setgw"
          fi
        else
          CFG[$CNT2]="setgw"
        fi
      fi

      if [ ${PARAM[$CNT]} = "-D" ] ; then		# Usuwanie wszystkich
        if [[ -n ${CFG[$CNT2]} ]] ; then		# lub wybranego kontenera
          if [[ "$TMP" = "-" ]] ; then
            CFG[$CNT2]="deldefaultnamecnt"
          fi
        else
          CFG[$CNT2]="deldefaultnamecnt"
        fi
      fi

      if [ ${PARAM[$CNT]} = "-U" ] ; then		# Aktualizacja danych 
        CFG[$CNT2]=0
      fi

      if [ ${PARAM[$CNT]} = "-v" ] ; then		# Wyswietlanie komunikatow
        CFG[$CNT2]=0
      fi

      if [ ${PARAM[$CNT]} = "-V" ] ; then		# Wyswietlanie komunikatow debugowania
        CFG[$CNT2]=0
      fi

    fi
  done
done

# Sprawdzenie i ewentualne utworzenie obrazów kontenerów Quaggalink i Qoslink
# ---------------------------------------------------------------------------
chk_crt_img_quaggalink
chk_crt_img_qoslink

# Podgląd tablicy CFG[]
# ---------------------
#for (( CNT=0; CNT<${#WSK[@]}; CNT++ )) ; do
#  echo "CFG[$CNT] = ${CFG[$CNT]} " 
#done

# Weryfikacja wprowadzonych parametrów i ich zależności
# -----------------------------------------------------

# ----  Weryfikacja parametru pasma 1 - BAND1
# Automatyczna wartość gdy tworzymy nowe łącze i nie podamy danego parametru
if [[ -z ${CFG[9]} && ! ${CFG[20]} ]] ; then
  CFG[9]="100Mbit" 
else
# W przeciwnym wypadku sprawdzamy jego poprawność 
  if [[ -n ${CFG[9]} ]] ; then
    chk_band 9			# Podaje pozycję parametru z tablicy WSK[] <=> -band1
  fi
fi

# ----  Weryfikacja parametru pasma 2 - BAND2
if [[ -z ${CFG[10]} && ! ${CFG[20]} ]] ; then
  CFG[10]="100Mbit"
else
  if [[ -n ${CFG[10]} ]] ; then
    chk_band 10
  fi
fi

# ----  Weryfikacja parametru utraty pakietów - LOSS1
if [[ -z ${CFG[11]} && ! ${CFG[20]} ]] ; then
  CFG[11]="0%"
else
  if [[ -n ${CFG[11]} ]] ; then
    chk_loss 11
  fi
fi

# ----  Weryfikacja parametru utraty pakietów - LOSS2
if [[ -z ${CFG[12]} && ! ${CFG[20]} ]] ; then
  CFG[12]="0%"
else
  if [[ -n ${CFG[12]} ]] ; then
    chk_loss 12
  fi
fi

# ----  Weryfikacja parametru opóżnienia - DELAY1
if [[ -z ${CFG[13]} && ! ${CFG[20]} ]] ; then
  CFG[13]="0ms"
else
  if [[ -n ${CFG[13]} ]] ; then
    chk_delay 13
  fi
fi

# ----  Weryfikacja parametru opóżnienia - DELAY2
if [[ -z ${CFG[14]} && ! ${CFG[20]} ]] ; then
  CFG[14]="0ms"
else
  if [[ -n ${CFG[14]} ]] ; then
    chk_delay 14
  fi
fi

# ----  Weryfikacja parametru duplicowania - DUPLIC1
if [[ -z ${CFG[28]} && ! ${CFG[20]} ]] ; then
  CFG[28]="0%"
else
  if [[ -n ${CFG[28]} ]] ; then
    chk_duplic 28
  fi
fi

# ----  Weryfikacja parametru duplicowania - DUPLIC2
if [[ -z ${CFG[29]} && ! ${CFG[20]} ]] ; then
  CFG[29]="0%"
else
  if [[ -n ${CFG[29]} ]] ; then
    chk_duplic 28
  fi
fi

# ----  Weryfikacja parametru pasma - BAND
# łącze symetryczne
if [[ -n ${CFG[34]} ]] ; then
  chk_band 34
  if [[ -n $ANS1 || -n $ANS2 ]] ; then
    CFG[9]=${CFG[34]}
    CFG[10]=${CFG[34]} 
  else
    die 60 "Niepoprawny format parametru -band"
  fi
fi

# ----  Weryfikacja parametru duplicowania - LOSS 
# Oblicza wartość -loss dla obu kierunków, aby otrzymać 
# wypadkowe prawdopodobieństwo utraty wg zadanej wartości.
if [[ -n ${CFG[35]} ]] ; then
  chk_loss 35
  if [[ -n $ANS1 ]] ; then      # Podawana wartość procentowa
    LOSS=(`echo ${CFG[35]} | awk -F% '{print $1}'`)
    LOSS=(`echo "scale=2; 100-$LOSS" | bc `)
    LOSS=$(echo "scale=2; sqrt($LOSS)" | bc)
    LOSS=$(echo "scale=2; (10-$LOSS)*10" | bc)
    CFG[11]=${LOSS}%
    CFG[12]=${LOSS}%
  fi
  if [[ -n $ANS2 ]] ; then	# Podawan3 wg ilości pakietów
    let LOSS=${CFG[35]}/2
    CFG[11]=${LOSS}
    CFG[12]=${LOSS}
  fi
fi

# ----  Weryfikacja parametru opóźnienia - DELAY
# Sumaryczne opóźnienie podzielone na oba kierunki
if [[ -n ${CFG[36]} ]] ; then
  chk_delay 36
  DELAY=`echo ${CFG[36]} | awk -Fm '{print $1}'`
  CFG[13]=`echo "scale=2; $DELAY/2" | bc `
  CFG[13]=${CFG[13]}ms
  CFG[14]=${CFG[13]}
fi

# ----  Weryfikacja parametru duplicowania - DUPLIC
# Oblicza wartość -duplic dla obu kierunków, aby otrzymać 
# wypadkowe prawdopodobieństwo powtarzania wg zadanej wartości.
if [[ -n ${CFG[37]} ]] ; then
  chk_duplic 37
  if [[ -n $ANS1 ]] ; then
    DUPLIC=(`echo ${CFG[37]} | awk -F% '{print $1}'`)
    DUPLIC=(`echo "scale=2; 100-$DUPLIC" | bc `)
    DUPLIC=$(echo "scale=2; sqrt($DUPLIC)" | bc)
    DUPLIC=$(echo "scale=2; (10-$DUPLIC)*10" | bc)
    CFG[28]=${DUPLIC}%
    CFG[29]=${DUPLIC}%
  fi
  if [[ -n $ANS2 ]] ; then
    let DUPLIC=${CFG[37]}/2
    CFG[28]=${DUPLIC}
    CFG[29]=${DUPLIC}
  fi
fi


# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!  do zrobienia  !!!!!!!!!!!!!!!
# ----  Weryfikacja nazwy łącza - LINK
if [[ -n ${CFG[15]} ]] ; then
  if ! checklink ${CFG[15]}  ; then
    die 8 "Niepoprawna nazwa łącza"
  fi
fi

# -----  Aktualizacja parametrów łącza QOSLINK -----
if [[ ${CFG[20]} ]] ; then
  if [[ -n ${CFG[0]} ]] ; then
    if checkcontainer "${CFG[0]}" ; then
      upgrade_link
    else
      die 51 "Brak kontenera o podanej nazwie: ${CFG[0]}"
    fi
  else
    die 50 "Nie podano nazwy kontenera -c"
  fi  
  msg "Gotowe."
  exit 0
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
    die 5 "Nazwa bridge'a z opcji -br2 ${CFG[8]} jest już utworzona w systemie"
  fi
fi

# -----  Weryfikacja switchy  ----------
if [[ -n ${CFG[16]} ]] ; then
  if checkswitch "${CFG[16]}" ; then
    msg "Nazwa switch'a z opcji -sw1 ${CFG[16]} jest już utworzona w systemie"
  fi
fi

if [[ -n ${CFG[17]} ]] ; then
  if checkswitch "${CFG[17]}" ; then
    msg "Nazwa switch'a z opcji -sw2 ${CFG[17]} jest już utworzona w systemie"
  fi
fi

# -----  Weryfikacja interfejsu  IF1 w H1  -----
if [[ -n ${CFG[3]} ]] ; then
  if checkinterface "${CFG[3]}" "${CFG[1]}" ; then
    die 5 "Nazwa interfejsu z opcji -if1 ${CFG[3]} jest już utworzona w kontenerze ${CFG[1]}"
  fi
fi

# -----  Weryfikacja interfejsu  IF2 w H2  -----
if [[ -n ${CFG[4]} ]] ; then
  if checkinterface "${CFG[4]}" "${CFG[2]}" ; then
    die 5 "Nazwa interfejsu z opcji -if2 ${CFG[4]} jest już utworzona w kontenerze ${CFG[2]}"
  fi
fi

# -----  Weryfikacja interfejsu  IF1 w R1  -----
if [[ -n ${CFG[3]} ]] ; then
  if checkinterface "${CFG[3]}" "${CFG[18]}" ; then
    die 5 "Nazwa interfejsu z opcji -if1 ${CFG[3]} jest już utworzona w kontenerze ${CFG[18]}"
  fi
fi

# -----  Weryfikacja interfejsu  IF2 w R2  -----
if [[ -n ${CFG[4]} ]] ; then
  if checkinterface "${CFG[4]}" "${CFG[19]}" ; then
    die 5 "Nazwa interfejsu z opcji -if2 ${CFG[4]} jest już utworzona w kontenerze ${CFG[19]}"
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

# ----  Usuwanie kontenerów
if [[ -n ${CFG[27]} ]] ; then
  del_container
  echo "Funkcja do zaprogramowania"
  exit
fi

# Podgląd tablicy z parametrami
# ---------------------
#for (( CNT=0; CNT<${#WSK[@]}; CNT++ )) ; do
#  echo "CFG[$CNT] -eq ${CFG[$CNT]} " 
#done

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

72)						# sw1       ---  h2
    freenet
    freeip $NEWNET
    CFG[6]=$NEWIP
    freeip $NEWNET
    CFG[23]=$NEWIP
    freeip $NEWNET
    CFG[24]=$NEWIP
    set_c
    set_br2
    set_sw1
    crt_c
    set_if2
    crt_linkif2
    set_if3
    crt_linkif3sw1
    set_if4
    crt_linkif4
    crt_brinqos
    set_link
    ;;   

9)						# sw1       ---  r2
    freenet
    freeip $NEWNET
    CFG[6]=$NEWIP
    freeip $NEWNET
    CFG[23]=$NEWIP
    freeip $NEWNET
    CFG[24]=$NEWIP
    set_c
    set_sw1
    set_br2
    crt_c
    set_r2
    crt_r2
    set_if2r2
    crt_linkif2r2
    set_if3
    crt_linkif3sw1
    set_if4
    crt_linkif4
    crt_brinqos
    set_link
    ;;    

132)						# h1        ---  sw2
    freenet
    freeip $NEWNET
    CFG[5]=$NEWIP
    freeip $NEWNET
    CFG[23]=$NEWIP
    freeip $NEWNET
    CFG[24]=$NEWIP
    set_c
    set_br1
    set_sw2
    crt_c
    set_if1
    crt_linkif1
    set_if3
    crt_linkif3
    set_if4
    crt_linkif4sw2
    crt_brinqos
    set_link
    ;;   

6)						# r1       ---  sw2
    freenet
    freeip $NEWNET
    CFG[5]=$NEWIP
    freeip $NEWNET
    CFG[23]=$NEWIP
    freeip $NEWNET
    CFG[24]=$NEWIP
    set_c
    set_sw2
    set_br1
    crt_c
    set_r1
    crt_r1
    set_if1r1
    crt_linkif1r1
    set_if3
    crt_linkif3
    set_if4
    crt_linkif4sw2
    crt_brinqos
    set_link
    ;;    

44)						# sw1 + ip1 ---  sw2
    checkipall ${CFG[5]}
    freeip ${CFG[5]}
    CFG[23]=$NEWIP
    freeip ${CFG[5]}
    CFG[24]=$NEWIP
    set_c
    set_sw1
    set_sw2
    crt_c
    set_if3
    crt_linkif3sw1
    set_if4
    crt_linkif4sw2
    crt_brinqos
    set_link
    ;;

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

164)						# h1        ---       sw2
    checkipall ${CFG[5]}
    freeip ${CFG[5]}
    CFG[23]=$NEWIP
    freeip ${CFG[5]}
    CFG[24]=$NEWIP
    set_c
    set_br1
    set_sw2
    crt_c
    set_if1
    crt_linkif1
    set_if3
    crt_linkif3
    set_if4
    crt_linkif4sw2
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

88)						#      sw1  ---  h2
    checkipall ${CFG[6]}
    freeip ${CFG[6]}
    CFG[23]=$NEWIP
    freeip ${CFG[6]}
    CFG[24]=$NEWIP
    set_c
    set_br2
    set_sw1
    crt_c
    set_if2
    crt_linkif2
    set_if3
    crt_linkif3sw1
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

38)						# r1 + ip1  ---       sw2
    checkipall ${CFG[5]}
    freeip ${CFG[5]}
    CFG[23]=$NEWIP
    freeip ${CFG[5]}
    CFG[24]=$NEWIP
    set_c
    set_br1
    set_sw2
    crt_c
    set_r1
    crt_r1
    set_if1r1
    crt_linkif1r1
    set_if3
    crt_linkif3
    set_if4
    crt_linkif4sw2
    crt_brinqos
    set_link 
    ;;


98)						# h1 + ip1  ---         r2
    checkipall ${CFG[5]}
    freeip ${CFG[5]}
    CFG[6]=$NEWIP
    freeip ${CFG[5]}
    CFG[23]=$NEWIP
    freeip ${CFG[5]}
    CFG[24]=$NEWIP
    set_c
    set_br1
    set_br2
    crt_c
    set_r1
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


35)						# h1 + ip1  ---         r2
    checkipall ${CFG[5]}
    freeip ${CFG[5]}
    CFG[6]=$NEWIP
    freeip ${CFG[5]}
    CFG[23]=$NEWIP
    freeip ${CFG[5]}
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
    ;;

25)						# sw1       ---  r2 + ip2
    checkipall ${CFG[6]}
    freeip ${CFG[6]}
    CFG[23]=$NEWIP
    freeip ${CFG[6]}
    CFG[24]=$NEWIP
    set_c
    set_br2
    set_sw1
    crt_c
    set_r2
    crt_r2
    set_if2r2
    crt_linkif2r2
    set_if3
    crt_linkif3sw1
    set_if4
    crt_linkif4
    crt_brinqos
    set_link 
    ;;

145)						# h1 + ip1  ---         r2
    checkipall ${CFG[6]}
    freeip ${CFG[6]}
    CFG[5]=$NEWIP
    freeip ${CFG[6]}
    CFG[23]=$NEWIP
    freeip ${CFG[6]}
    CFG[24]=$NEWIP
    set_c
    set_br1
    set_br2
    crt_c
    set_r2
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


19)						# h1 + ip1  ---         r2
    checkipall ${CFG[6]}
    freeip ${CFG[6]}
    CFG[5]=$NEWIP
    freeip ${CFG[6]}
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
    ;;


177)						# r1 + ip1  ---  h2 + ip2  
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
      set_r2
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
    else     
      exit 0
    fi
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


114)						# r1 + ip1  ---  h2 + ip2  
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

3)
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

echo Gotowe
exit 0
