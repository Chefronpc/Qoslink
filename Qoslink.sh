#!/bin/bash

# Parametry wstępne -  Globalne
# ----------------	# Domyślne nazwy:
BRPREFIX="brlink"	# bridgy
BRMAX=1024		
SWPREFIX="brswitch"     # switchy
SWMAX=512
QOSPREFIX="qoslink"	# kontenerów łączy
QOSMAX=256
HOSTPREFIX="host"	# domyslnych hostów
HOSTMAX=256
QUAGGAPREFIX="quaggalink" # routerów
QUAGGAMAX=256
PHPREFIX="phlink"	# routerów brzegowych
PHMAX=256
IFPREFIX="eth"		# interfejsów w kontenerach
IFMAX=64
FILEPREFIX="testsdn"	# Domyślna nazwa pliku
FILEMAX=1024
DEFAULTNET="10.0.0.0/24"   # Domyślny adres sieci. Obsluga pełnego zakresu adresacji 
			   # Zakres obsługiwanej maski <2,29>	

R="\e[31m"  		# Kolory komunikatów
Y="\e[33m"
G="\e[32m"
B="\e[34m"
BLK="\e[30m"
RB="\e[31;1m"  		# pogrubione
YB="\e[33;1m"
GB="\e[32;1m"
BB="\e[34;1m"
BLKB="\e[30;1m"
BCK="\e[0m"   		# powrót do stadanrdowego zestawu kolorów terminala


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
  msg "Tworzenie pliku dokerfiles w celu utworzenia kontenera qoslink"
  mkdir ./dockerfiles
  cd ./dockerfiles
  echo "FROM centos:6.6" > dockerfile
  echo "MAINTAINER Czyz Piotr" >> dockerfile
  
  echo "RUN yum -y update" >> dockerfile
  echo "RUN yum -y install bridge-utils net-tools mtr tar nmap telnet wget tcpdump" >> dockerfile
  
  echo "RUN wget https://iperf.fr/download/iperf_2.0.2/iperf_2.0.2-4_amd64.tar.gz \\" >> dockerfile
  echo "&& tar zxf iperf_2.0.2-4_amd64.tar.gz \\" >> dockerfile
  echo "&& cp /iperf_2.0.2-4_amd64/iperf . \\" >> dockerfile
  echo "&& rm -Rf iperf_2.0.2-4_amd64 \\" >> dockerfile
  echo "&& rm -f iperf_2.0.2-4_amd64.tar.gz" >> dockerfile
  cd ../
}

crt_dockerfile_quaggalink() {
  msg "Tworzenie pliku dokerfiles w celu utworzenia kontenera quaggalink"
  mkdir ./dockerfiles
  cd ./dockerfiles
  echo "FROM centos:6.6" > dockerfile
  echo "MAINTAINER Czyz Piotr" >> dockerfile

  echo "RUN yum -y update" >> dockerfile
  echo "RUN yum -y install bridge-utils net-tools mtr tar nmap telnet wget tcpdump quagga" >> dockerfile
  
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
  # Sprawdzenie obecności obrazu Centos 6.6 w lokalnym repozytorium
  if [[ -z $LISTIMAGES ]] ; then
    msg "Pobieranie skompresowanego obrazu systemu CentOS 6.6"
    if [ ! -e "./centos-6-20150615_2019-docker.tar.xz" ] ; then
      wget https://github.com/CentOS/sig-cloud-instance-images/blob/311d80f2e558eba3a6ea88c387714ae2e4175702/docker/centos-6-20150615_2019-docker.tar.xz?raw=true > ./wgetcentos.log 2>&1
      STAT1=(`cat ./wgetcentos.log | grep "saved"`)
      if [[ -n $STAT1 ]] ; then
        mv centos-6-20150615_2019-docker.tar.xz\?raw\=true centos-6-20150615_2019-docker.tar.xz
        rm -f ./wgetcentos.log
      else
        die 82 "Błąd przy pobieraniu obrazu Centos 6.6"
      fi 
    fi
    if [ ! -e "./Dockerfile" ] ; then
      wget https://github.com/CentOS/sig-cloud-instance-images/raw/311d80f2e558eba3a6ea88c387714ae2e4175702/docker/Dockerfile > ./wgetdockerfile.log 2>&1
      STAT2=(`cat ./wgetdockerfile.log | grep "saved"`)
      if [[ ! -n $STAT2 ]] ; then
        die 83 "Błąd przy pobieraniu pliku Dockerfile dla systemu Centos 6.6"
      fi
      rm -f ./wgetdockerfile.log
    fi
    msg "Budowanie obrazu Centos 6.6"
    docker build . > ./centos66.log 2>&1
    IDCon=(`cat ./centos66.log | grep Successfully | awk '{ print $(NF) }' `)
    if [[ -n $IDCon ]] ; then
      docker tag $IDCon centos:6.6
      msg "Utworzono obraz centos:6.6 "
      rm -f centos-6-20150615_2019-docker.tar.xz
      rm -f Dockerfile
    else
      die 84 "Błąd przy budowaniu obrazu Centos 6.6"
    fi
  fi
}

# Sprawdzanie dostępności obrazu qoslink w repozytorium lokalnym / ew. utworzenie
chk_crt_img_qoslink() {
  # sprawdzenie lokalnego repozytorium
  LISTIMAGES=(`docker images | awk '/chefronpc\/qoslink/ {print}' `)
  if [[ -z $LISTIMAGES ]] ; then
    msg "${Y}Brak obrazu kontenera qoslink w lokalnym repozytorium...${BCK}"
    # Sprawdzenie dostępności obrazu qoslink w repo Docker
    LISTIMAGES=(`docker search qoslink | awk '/chefronpc\/qoslink/ {print}' `)
    if [[ -z $LISTIMAGES ]] ; then
      msg "${Y}Brak obrazu kontenera qoslink w zdalnym repozytorium Dockera${BCK}"
      # Sprawdzenie dostęności obrazu Centos 6.6 i ewentualne utworzenie
      chk_crt_img_centos66 
      # Tworzenie pliku dockerfile dla konfiguracji kontenera Qoslink
      crt_dockerfile_qoslink
      msg "Tworzenie kontenera qoslink..."
      STAT=(`docker build ./dockerfiles/`)
      IDCon=(`echo ${STAT[@]} | grep Successfully | awk '{ print $(NF) }' `)
      docker tag $IDCon chefronpc/qoslink:v1
      msg "Utworzono kontener qoslink"
      rm -rf ./dockerfiles
    else
      # Pobranie obrazu qoslink ze zdalnego repo Docker'a
      msg "Pobranie obrazu qoslink ze zdalnego repozytorium Dockera"
      docker pull chefronpc/qoslink:v1
    fi
  fi
}

# Sprawdzanie dostępności obrazu quaggalink w repozytorium lokalnym / ew. utworzenie
chk_crt_img_quaggalink() {
  LISTIMAGES=(`docker images | awk '/chefronpc\/quaggalink/ {print}' `)
  if [[ -z $LISTIMAGES ]] ; then
    msg "${Y}Brak obrazu kontenera quaggalink w lokalnym repozytorium...${BCK}"
    # Sprawdzenie dostępności obrazu quaggalink w repo Docker
    LISTIMAGES=(`docker search quaggalink | awk '/chefronpc\/quaggalink/ {print}' `)
    if [[ -z $LISTIMAGES ]] ; then
      # Sprawdzenie dostęności obrazu Centos 6.6 i ewentualne utworzenie
      msg "${Y}Brak obrazu kontenera quaggalink w zdalnym repozytorium Dockera${BCK}"
      chk_crt_img_centos66 
      # Tworzenie pliku dockerfile dla konfiguracji kontenera Quaggalink
      crt_dockerfile_quaggalink
      msg "Tworzenie kontenera quaggalink..."
      STAT=(`docker build ./dockerfiles`)
      IDCon=(`echo ${STAT[@]} | grep Successfully | awk '{ print $(NF) }' `)
      docker tag $IDCon chefronpc/quaggalink:v1
      msg "Utworzono kontener quaggalink"
      rm -rf ./dockerfiles
    else
      # Pobranie obrazu quaggalink ze zdalnego repo Dokcer'a
      msg "Pobranie obrazu quaggalink ze zdalnego repozytorium Dockera"
      docker pull chefronpc/quaggalink:v1
    fi
  fi
}

# Sprawdza dostępność bridga
# We - $1 nazwa bridga
# --------------------------
checkbridge() {

#  LISTALL=(`nmcli d | awk '{ print $1 }'`)
  LISTALL=(`nmcli d | grep $1 `)
#  ISBRIDGE=(`nmcli d | grep " bridge " | grep $1 | awk '{ print $1 }'`)
  ISBRIDGE=(`nmcli d | grep " bridge " | grep $1`)
  if [[ -n $LISTALL ]] ; then  
    if [[ -n $ISBRIDGE ]] ; then 
      die 66 "Bridge o nazwie $1 jest już utworzony w systemie."
    else
      die 67 "Podano nazwę bridga zajętą już przez inny interfejs w systemie."
    fi
  else
    if [[ -n $ISBRIDGE ]] ; then
      return 0		# Nazwa bridga zajęta
    else 			
      return 1		# Podana nazwa bridga jest wolna w systemie
    fi
  fi
  die 68 "Błąd w funkcji checkbridge"
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

# Sprawdza dostępność Hosta
# We - $1 nazwa kontenera
# --------------------------
checkhost() {
  LISTHOST=(`docker ps -a | sed -n -e '1!p' | awk '{ print $(NF) }' `)
  for (( CNT=0; CNT<${#LISTHOST[@]}; CNT++ )) ; do
    if [[ "$1" = "${LISTHOST[$CNT]}" ]] ; then
      return 0
    fi
  done
  return 1
}
 
# Zwraca numer pierwszego wolnego hosta
# Wy - nazwa kontenera
# --------------------------------
freehost() {
  LISTHOST=(`docker ps -a | sed -n -e '1!p' | awk '{ print $(NF) }' `)
  for (( CNT=0; CNT<$HOSTMAX; CNT++ )) ; do
    PASS=0 
    ANS=(`echo ${LISTHOST[@]} | grep $HOSTPREFIX$CNT `)
    if [[ -n ${ANS[@]} ]] ; then
      PASS=1
    fi
    if [[ $PASS -eq 0 ]] ; then
      HOSTNAME=$HOSTPREFIX$CNT 		# Wyszukana wolna nazwa dla nowego routera (kontenera)
      return 0
    fi
  done
  die 5 "Brak wolnych hostów"
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
 
# Sprawdza dostępność łącza phlink
# We - $1 nazwa kontenera
# --------------------------
checkphlink() {
  LISTPHLINK=(`docker ps -a | sed -n -e '1!p' | awk '{ print $(NF) }' `)
  for (( CNT=0; CNT<${#LISTPHLINK[@]}; CNT++ )) ; do
    if [[ "$1" = "${LISTPHLINK[$CNT]}" ]] ; then
      return 0
    fi
  done
  return 1
}
 
# Zwraca numer pierwszego wolnego łącza phlink
# Wy - nazwa kontenera
# --------------------------------
freephlink() {
  LISTPHLINK=(`docker ps -a | sed -n -e '1!p' | awk '{ print $(NF) }' `)
  for (( CNT=0; CNT<$PHMAX; CNT++ )) ; do
    PASS=0 
    ANS=(`echo ${LISTPHLINK[@]} | grep $PHPREFIX$CNT `)
    if [[ -n ${ANS[@]} ]] ; then
      PASS=1
    fi
    if [[ $PASS -eq 0 ]] ; then
      PHNAME=$PHPREFIX$CNT 		# Wyszukana wolna nazwa dla nowego łącza phlink (kontenera)
      return 0
    fi
  done
  die 5 "Brak wolnych łączy phlink"
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

# Sprawdza dostępnosc parametrów sieci we wszystkich kontenerach
# We - $1 IP/Netmask
# ------------------------------------
checkipall() {
  msg "Weryfikacja adresu IP $1 we wszystkich kontenerach" 
  if parseip "$1" ; then
    # Sprawdza czy IP jest adresem sieci czy broadcastem 
    comparenet "$1" "0.0.0.0"
    NET11="${NET1[0]}.${NET1[1]}.${NET1[2]}.${NET1[3]}/$M1"
    if [[ "$NET11" == "$1" ]] ; then
      die 64 "Adres IP $1 nie może być adresem sieci."
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

# ---- Uzupełnianie brakujących parametrów
# ----------------------------------------------
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

# ---- Przypisanie nazwy dla Hosta <h1>
set_h1() {
if [[ "${CFG[1]}" = "setnamecnthost" ]] ; then
  if freehost ; then 
    CFG[1]=$HOSTNAME
    NEWHOST1="tak"		# Znacznik dla utworzenia nowego kontenera hosta
    msg "Przypisano nazwę hosta w kontenerze -h1: <${G}${CFG[1]}${BCK}>"
  fi
else
  if ! checkhost "${CFG[1]}" ; then
    NEWHOST1="tak"		# Utworzy kontener o podanej nazwie hosta
  fi
fi
return 0
}

# ---- Przypisanie nazwy dla Hosta <h2>
set_h2() {
if [[ "${CFG[2]}" = "setnamecnthost" ]] ; then
  if freehost ; then 
    CFG[2]=$HOSTNAME
    NEWHOST2="tak"		# Znacznik dla utworzenia nowego kontenera hosta
    msg "Przypisano nazwę hosta w kontenerze -h2: <${G}${CFG[2]}${BCK}>"
  fi
else
  if ! checkhost "${CFG[2]}" ; then
    NEWHOST2="tak"		# Utworzy kontener o podanej nazwie hosta
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

# ---- Przypisanie nazwy dla phlink - łącza do zewnetrznego interfejsu <ph1>
set_ph1() {
if [[ "${CFG[32]}" == "setnamecntph" ]] ; then
  if freephlink ; then 
    CFG[32]=$PHNAME
    msg "Przypisano nazwę łącza wyjściowego w kontenerze -ph1: <${G}${CFG[32]}${BCK}>"
  fi
fi
return 0
}

# ---- Przypisanie nazwy dla phlink - łącza do zewnetrznego interfejsu <ph2>
set_ph2() {
if [[ "${CFG[33]}" == "setnamecntph" ]] ; then
  if freephlink ; then 
    CFG[33]=$PHNAME
    msg "Przypisano nazwę łącza wyjściowego w kontenerze -ph2: <${G}${CFG[33]}${BCK}>"
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

# -----  Przypisanie nazwy dla interfejsu <if1> w łączu phlink <-ph1>  -------
set_if1ph1() {
if [[ -z ${CFG[3]} ]] ; then
  if freeinterface "${CFG[32]}" ; then
    CFG[3]=$IFNAME
    msg "Przypisano nazwę interfejsu -if1: <${G}${CFG[3]}${BCK}> ip:<${G}${CFG[5]}${BCK}> w kontenerze <${G}${CFG[32]}${BCK}>"
  fi
fi
return 0
}

# -----  Przypisanie nazwy dla interfejsu <if2> w łączu phlink <-ph2>  -------
set_if2ph2() {
if [[ -z ${CFG[4]} ]] ; then
  if freeinterface "${CFG[33]}" ; then
    CFG[4]=$IFNAME
    msg "Przypisano nazwę interfejsu -if2: <${G}${CFG[4]}${BCK}> ip:<${G}${CFG[6]}${BCK}> w kontenerze <${G}${CFG[33]}${BCK}>"
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

# -----  Tworzenie kontenerów qoslink oraz quaggalink
# -----------------------------------------------------
# -----  Uruchomienie kontenera łączącego hosty ( QoSLink )
crt_c() {
  ANS=(` docker run -d -ti --name ${CFG[0]} --hostname ${CFG[0]} --net none --cap-add All chefronpc/qoslink:v1 /bin/bash `)
  msg "Uruchomienie kontenera łączącego ${CFG[0]}"
}

# -----  Uruchomienie kontenera -h1 - Host
crt_h1() {
  if [[ "$NEWHOST1" = "tak" ]] ; then
  #  ANS=(` docker run -d -ti --name ${CFG[1]} --hostname ${CFG[1]} --cap-add ALL chefronpc/host:v1 /bin/bash `) 
    ANS=(` docker run -d -ti --name ${CFG[1]} --hostname ${CFG[1]} --net none --cap-add ALL chefronpc/host:v1 /bin/bash `) 
    msg "Uruchomienie hosta w kontenerze ${CFG[1]}"
  fi
  return
}

# -----  Uruchomienie kontenera -h2 - Host
crt_h2() {
  if [[ "$NEWHOST2" = "tak" ]] ; then
  #  ANS=(` docker run -d -ti --name ${CFG[2]} --hostname ${CFG[2]} --cap-add ALL chefronpc/host:v1 /bin/bash `) 
    ANS=(` docker run -d -ti --name ${CFG[2]} --hostname ${CFG[2]} --net none --cap-add ALL chefronpc/host:v1 /bin/bash `) 
    msg "Uruchomienie hosta w kontenerze ${CFG[2]}"
  fi
  return
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
    NEWROUTER="new"		# znacznik nowego routera - wymagany przy tworzeniu ID-Routera
    return		# jeżeli nowy -> tworzy ID-Routera wg nr IP
  fi
  msg "Router Quagga w kontenerze ${Y}${CFG[19]} jest już w systemie${BCK}"
  msg "Skonfigurowany zostanie ${Y}dodatkowy interfejs w ${CFG[19]}${BCK} z adresem ${Y}${CFG[6]}${BCK}"
  NEWROUTER="old"		# Jeżeli już był uruchomiony -> znacznik umozliwiający
			# pozostawienie istniejącego ID-routera
}

# -----  Uruchomienie kontenera -ph1 - Łącza PhLink do hosta fizycznego
crt_ph1() {
  if ! checkphlink "${CFG[32]}" ; then
    ANS=(` docker run -d -ti --name ${CFG[32]} --hostname ${CFG[32]} --net bridge --cap-add ALL chefronpc/quaggalink:v1 /bin/bash `) 
    ANS=(` docker exec ${CFG[32]} /bin/bash -c 'service zebra start && service ospfd start' `)
    ANS=(` docker exec ${CFG[32]} /bin/bash -c 'vtysh -e "configure terminal" -e "log file /var/log/quagga/quagga.log" -e "exit" -e "write" ' `)
    msg "Uruchomienie łącza phlink w kontenerze ${CFG[32]}"
    NEWPHLINK="new"	# znacznik nowego łącza phlink - wymagany przy tworzeniu ID-Routera
    return		# jeżeli nowy -> tworzy ID-Routera wg nr IP
  fi
  msg "Łącze PhLink w kontenerze ${Y}${CFG[32]} jest już w systemie${BCK}"
  msg "Skonfigurowany zostanie ${Y}dodatkowy interfejs w ${CFG[32]}${BCK} z adresem ${Y}${CFG[5]}${BCK}"
  NEWPHLINK="old"	# Jeżeli już był uruchomiony -> pozostawia istniejący ID-routera
}

# -----  Uruchomienie kontenera -ph2 - Łącza PhLink do hosta fizycznego
crt_ph2() {
  if ! checkphlink "${CFG[33]}" ; then
    ANS=(` docker run -d -ti --name ${CFG[33]} --hostname ${CFG[33]} --net bridge --cap-add ALL chefronpc/quaggalink:v1 /bin/bash `) 
    ANS=(` docker exec ${CFG[33]} /bin/bash -c 'service zebra start && service ospfd start' `)
    ANS=(` docker exec ${CFG[33]} /bin/bash -c 'vtysh -e "configure terminal" -e "log file /var/log/quagga/quagga.log" -e "exit" -e "write" ' `)
    msg "Uruchomienie łącza phlink w kontenerze ${CFG[33]}"
    NEWPHLINK="new"	# znacznik nowego łącza phlink - wymagany przy tworzeniu ID-Routera
    return		# jeżeli nowy -> tworzy ID-Routera wg nr IP
  fi
  msg "Łącze PhLink w kontenerze ${Y}${CFG[33]} jest już w systemie${BCK}"
  msg "Skonfigurowany zostanie ${Y}dodatkowy interfejs w ${CFG[33]}${BCK} z adresem ${Y}${CFG[6]}${BCK}"
  NEWPHLINK="old"	# Jeżeli już był uruchomiony -> pozostawia istniejący ID-routera
}


# -----  Tworzenie połączen pomiędzy bridgem a kontenerem
# -------------------------------------------------------------
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
    msg "Polaczenie bridg'a -br2 ${CFG[8]} z hostem ${CFG[2]} gateway:${CFG[31]}"
  else  
    msg "Polaczenie bridg'a -br2 ${CFG[8]} z hostem ${CFG[2]}"
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
  ANS=(`docker exec ${CFG[18]} vtysh -c "configure terminal" -c "interface ${CFG[3]}" -c "ip address ${CFG[5]}" -c "description to-${CFG[0]}" -c "ip ospf hello-interval 5" -c "ip ospf dead-interval 10" -c "no shutdown" -c "exit" -c "exit" -c "write" `)
  # Odczytanie adresu sieci na podstawie IP i Maski
  NET1=(` ipcalc ${CFG[5]} -n | awk -F= '{print $2}' | awk -F. '{print $1,$2,$3,$4}' `)
  M1=(`echo ${CFG[5]} | awk -F/ '{print $2}' `)
  NEWNET="${NET1[0]}.${NET1[1]}.${NET1[2]}.${NET1[3]}/$M1"
  # Utworzenie ID routera na podstawie adresu IP - gwarancja niepowtarzalności
  ID=(`echo ${CFG[5]} | awk -F'/' '{print $1}' `)
  # Konfiguracja daemona OSPF w routerze
  ANS=(` docker exec ${CFG[18]} vtysh -c "configure terminal" -c "router ospf" -c "network $NEWNET area 1" -c "exit" -c "exit" -c "write" `)
  #ANS=(` service stop ospfd `)
  #ANS=(` service restart zebraa `)
  #ANS=(` service start ospfd `)
  msg "Konfiguracja daemona ZEBRA oraz OSPF w routerze ${CFG[18]}"
}

crt_linkif2r2() {
  pipework ${CFG[8]} -i ${CFG[4]} ${CFG[19]} ${CFG[6]}
  msg "Polaczenie bridg'a -br1 ${CFG[8]} z routerem ${CFG[19]}"
  # Konfiguracja daemona ZEBRA w routerze
  ANS=(` docker exec ${CFG[19]} vtysh -c "configure terminal" -c "interface ${CFG[4]}" -c "ip address ${CFG[6]}" -c "description to-${CFG[0]}" -c "ip ospf hello-interval 5" -c "ip ospf dead-interval 10" -c "no shutdown" -c "exit" -c "exit" -c "write" `)
  # Odczytanie adresu sieci na podstawie IP i Maski
  NET1=(` ipcalc ${CFG[6]} -n | awk -F= '{print $2}' | awk -F. '{print $1,$2,$3,$4}' `)
  M1=(`echo ${CFG[6]} | awk -F/ '{print $2}' `)
  NEWNET="${NET1[0]}.${NET1[1]}.${NET1[2]}.${NET1[3]}/$M1"
  # Utworzenie ID routera na podstawie adresu IP - gwarancja niepowtarzalności
  ID=(`echo ${CFG[6]} | awk -F'/' '{print $1}' `)
  # Konfiguracja daemona OSPF w routerze
  ANS=(` docker exec ${CFG[19]} vtysh -c "configure terminal" -c "router ospf" -c "network $NEWNET area 1" -c "exit" -c "exit" -c "write" `)
  #ANS=(` service stop ospfd `)
  #ANS=(` service restart zebraa `)
  #ANS=(` service start ospfd `)
  msg "Konfiguracja daemona ZEBRA oraz OSPF w routerze ${CFG[19]}"
}

crt_linkif1ph1() {
  pipework ${CFG[7]} -i ${CFG[3]} ${CFG[32]} ${CFG[5]}
  msg "Polaczenie bridg'a -br1 ${CFG[7]} z łączem phlink ${CFG[32]}"
  # Konfiguracja daemona ZEBRA w routerze
  ANS=(`docker exec ${CFG[32]} vtysh -c "configure terminal" -c "interface ${CFG[3]}" -c "ip address ${CFG[5]}" -c "description to-${CFG[0]}" -c "ip ospf hello-interval 5" -c "ip ospf dead-interval 10" -c "no shutdown" -c "exit" -c "exit" -c "write" `)
  # Odczytanie adresu sieci na podstawie IP i Maski
  NET1=(` ipcalc ${CFG[5]} -n | awk -F= '{print $2}' | awk -F. '{print $1,$2,$3,$4}' `)
  M1=(`echo ${CFG[5]} | awk -F/ '{print $2}' `)
  NEWNET="${NET1[0]}.${NET1[1]}.${NET1[2]}.${NET1[3]}/$M1"
  # Utworzenie ID routera na podstawie adresu IP - gwarancja niepowtarzalności
  ID=(`echo ${CFG[5]} | awk -F'/' '{print $1}' `)
  # Konfiguracja daemona OSPF w routerze
  ANS=(` docker exec ${CFG[32]} vtysh -c "configure terminal" -c "router ospf" -c "network $NEWNET area 1" -c "exit" -c "exit" -c "write" `)
  #ANS=(` service stop ospfd `)
  #ANS=(` service restart zebraa `)
  #ANS=(` service start ospfd `)
  msg "Konfiguracja daemona ZEBRA oraz OSPF w łączu phlink ${CFG[32]}"
}

crt_linkif2ph2() {
  pipework ${CFG[8]} -i ${CFG[4]} ${CFG[33]} ${CFG[6]}
  msg "Polaczenie bridg'a -br2 ${CFG[8]} z łączem phlink ${CFG[33]}"
  # Konfiguracja daemona ZEBRA w routerze    
  ANS=(`docker exec ${CFG[33]} vtysh -c "configure terminal" -c "interface ${CFG[4]}" -c "ip address ${CFG[6]}" -c "description to-${CFG[0]}" -c "ip ospf hello-interval 5" -c "ip ospf dead-interval 10" -c "no shutdown" -c "exit" -c "exit" -c "write" -c "exit" `)
  # Odczytanie adresu sieci na podstawie IP i Maski
  NET1=(` ipcalc ${CFG[6]} -n | awk -F= '{print $2}' | awk -F. '{print $1,$2,$3,$4}' `)
  M1=(`echo ${CFG[6]} | awk -F/ '{print $2}' `)
  NEWNET="${NET1[0]}.${NET1[1]}.${NET1[2]}.${NET1[3]}/$M1"
  # Utworzenie ID routera na podstawie adresu IP - gwarancja niepowtarzalności
  ID=(`echo ${CFG[6]} | awk -F'/' '{print $1}' `)
  # Konfiguracja daemona OSPF w routerze
  ANS=(` docker exec ${CFG[33]} vtysh -c "configure terminal" -c "router ospf" -c "network $NEWNET area 1" -c "exit" -c "exit" -c "write" -c "exit" `)
  #ANS=(` service stop ospfd `)
  #ANS=(` service restart zebraa `)
  #ANS=(` service start ospfd `)
  msg "Konfiguracja daemona ZEBRA oraz OSPF w łączu phlink ${CFG[33]}"
}

crt_linkif1docker0() {
#  pipework ${CFG[8]} -i ${CFG[4]} ${CFG[33]} ${CFG[6]}
  IPM5=(`docker exec ${CFG[32]} ip a | grep eth0 | awk '/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\// {print $2,$(NF)}' `)
  IP5=(`echo $IPM5 | awk -F/ '{print $1}' `)
  msg "Polaczenie łącza phlink ${CFG[32]}"
  # Konfiguracja daemona ZEBRA w routerze
  ANS=(`docker exec ${CFG[32]} vtysh -c "configure terminal" -c "interface eth0" -c "ip address ${IPM5}" -c "description to-docker0" -c "ip ospf hello-interval 5" -c "ip ospf dead-interval 10" -c "no shutdown" -c "exit" -c "exit" -c "write" `)
  # Odczytanie adresu sieci na podstawie IP i Maski
  NET1=(` ipcalc ${IPM5} -n | awk -F= '{print $2}' | awk -F. '{print $1,$2,$3,$4}' `)
  M1=(`echo ${IPM5} | awk -F/ '{print $2}' `)
  NEWNET="${NET1[0]}.${NET1[1]}.${NET1[2]}.${NET1[3]}/$M1"
  # Konfiguracja daemona OSPF w routerze
  ANS=(` docker exec ${CFG[32]} vtysh -c "configure terminal" -c "router ospf" -c "network $NEWNET area 0" -c "default-information originate always" -c "exit" -c "ip route 0.0.0.0 0.0.0.0 ${IP5}" -c "exit" -c "write" `)
  #ANS=(` service stop ospfd `)
  #ANS=(` service restart zebraa `)
  #ANS=(` service start ospfd `)
  ANS=(` docker exec ${CFG[32]} iptables -t nat -A POSTROUTING -s 0.0.0.0/0 -o eth0 -j SNAT --to-source ${IP5} `)
  msg "Konfiguracja daemona ZEBRA oraz ${G}OSPF${BCK} w łączu phlink ${G}${CFG[32]}${BCK}"
}

crt_linkif2docker0() {
  IPM5=(`docker exec ${CFG[33]} ip a | grep eth0 | awk '/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\// {print $2,$(NF)}' `)
  IP5=(`echo $IPM5 | awk -F/ '{print $1}' `)
  msg "Polaczenie łącza phlink ${CFG[33]}"
  # Konfiguracja daemona ZEBRA w routerze
  ANS=(` docker exec ${CFG[33]} vtysh -c "configure terminal" -c "interface eth0" -c "ip address ${IPM5}" -c "description to-${IP5}" -c "ip ospf hello-interval 5" -c "ip ospf dead-interval 10" -c "no shutdown" -c "exit" -c "exit" -c "write" -c "exit" `)
  # Odczytanie adresu sieci na podstawie IP i Maski
  NET1=(` ipcalc ${IPM5} -n | awk -F= '{print $2}' | awk -F. '{print $1,$2,$3,$4}' `)
  M1=(`echo ${IPM5} | awk -F/ '{print $2}' `)
  NEWNET="${NET1[0]}.${NET1[1]}.${NET1[2]}.${NET1[3]}/$M1"
  # Konfiguracja daemona OSPF w routerze
  ANS=(` docker exec ${CFG[33]} vtysh -c "configure terminal" -c "router ospf" -c "network $NEWNET area 0" -c "default-information originate always" -c "exit" -c "ip route 0.0.0.0 0.0.0.0 ${IP5}" -c "exit" -c "write" -c "exit" `)
  #ANS=(` service stop ospfd `)
  #ANS=(` service restart zebraa `)
  #ANS=(` service start ospfd `)
  ANS=(` docker exec ${CFG[33]} iptables -t nat -A POSTROUTING -s 0.0.0.0/0 -o eth0 -j SNAT --to-source ${IP5} `)
  msg "Konfiguracja daemona ZEBRA oraz ${G}OSPF${BCK} w łączu phlink ${G}${CFG[33]}${BCK}"
}

crt_linkif3sw1() {
  pipework ${CFG[16]} -i ${CFG[25]} ${CFG[0]} ${CFG[23]}
  msg "Polaczenie switch'a -sw1 ${G}${CFG[16]}${BCK} z kontenerem ${G}${CFG[0]}${BCK}"
}

crt_linkif4sw2() {
  pipework ${CFG[17]} -i ${CFG[26]} ${CFG[0]} ${CFG[24]}
  msg "Polaczenie switch'a -sw1 ${G}${CFG[17]}${BCK} z kontenerem ${G}${CFG[0]}${BCK}"
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
  rm -f buffor_cfg.dat
}


upgrade_link() {
  rm -f buffor_cfg.dat
  docker cp $1:/buffor_cfg.dat buffor_cfg.dat
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
  if [[ -n ${CFG[15]} ]] ; then
    CFG2[15]=${CFG[15]}
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
  docker cp buffor_cfg.dat $1:/buffor_cfg.dat
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

# Lista typów łączy
# ------------------
LINK=( 10Mbps 100Mbps 1Gbps ADSL3/8 ISDNBRI SDI 802.11b 802.11a 802.11g 802.11n )  

#  Konfiguruje komplet parametrów łącza
#  -band -loss -delay -duplic
#  według podanego typu z listy
# We - $1 Parametr -link $CFG[15]
# -------------------------------------
checklink() {
case "$1" in
  "10Mbps")
    CFG[9]=10Mbit   ; CFG[10]=10Mbit
    CFG[11]=0%      ; CFG[12]=0%
    CFG[13]=0.3ms   ; CFG[14]=0.3ms
    CFG[28]=0.01%  ; CFG[29]=0.01% 
    ;;
  "100Mbps")
    CFG[9]=100Mbit  ; CFG[10]=100Mbit
    CFG[11]=0%      ; CFG[12]=0%
    CFG[13]=0.2ms   ; CFG[14]=0.2ms
    CFG[28]=0.01%  ; CFG[29]=0.01%
    ;;
  "1Gbps")
    CFG[9]=1000Mbit  ; CFG[10]=1000Mbit
    CFG[11]=0.01%      ; CFG[12]=0.01%
    CFG[13]=0.2ms   ; CFG[14]=0.2ms
    CFG[28]=0.001%  ; CFG[29]=0.001%
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
    CFG[28]=0.05%   ; CFG[29]=0.05%
    ;;
  "SDI")
    CFG[9]=115kbit  ; CFG[10]=115kbit
    CFG[11]=0.3%    ; CFG[12]=0.3%
    CFG[13]=2ms     ; CFG[14]=2ms
    CFG[28]=0.1%    ; CFG[29]=0.1%
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
  ".")
    : # :
    ;;
  *)
    for (( CNT=0; CNT<${#LINK[@]}; CNT++ )) ; do
      message="$message   ${LINK[$CNT]}"
    done
    die 58 "Nieprawidłowy parametr -link \nDostępne: \n         $message"
esac
return 0
}

# -----  Aktualizacja parametrów łącza QOSLINK 
# ----- Po nazwie kontenera Qoslink lub adresie IP interfejsu
# ------------------------------------------------------------
upgrade_container() {
  STAT3="nie"					# Czy wykonano aktualizację
  if [[ -n ${CFG[15]} ]] ; then			# Sprawdzenie poprawności
    if ! checklink ${CFG[15]}  ; then		# i wczytanie parametrów łącza
      die 8 "Niepoprawna nazwa łącza"
    fi
  fi
  ANS=(`docker ps -a | grep ${CFG[20]}`)
  if [[ -n $ANS ]] ; then
    # ---  Aktualizacja po nazwie kontenera Qoslink
    CONTAINERLINK=(` docker inspect ${CFG[20]} | grep /qoslink: `)
    CONTAINERRUN=(` docker inspect ${CFG[20]} | grep -E "Running.*true" `)
    if [[ ! -n $CONTAINERRUN ]] ; then			# Kontener zatrzyman
      die 61 "Podany kontener <${CFG[20]}> jest zatrzymany"
  
    elif [[ -n $CONTAINERLINK ]] ; then			# Kontener typu qoslink
      upgrade_link ${CFG[20]}
      msg "Gotowe."
      exit 0
    else
      die 62 "Podany kontener ${CFG[20]} nie zawiera informacji o parametrach łącza"
    fi
  else
    # ---   Aktualizacja po adresie IP
    LISTCONTAINER=(`docker ps -a | sed -n -e '1!p' | awk '{ print $2,$(NF) }' `)
    let CNTMAX=${#LISTCONTAINER[@]*2}
    for (( CNT3=0; CNT3<$CNTMAX; CNT3=CNT3+2 )) ; do
      ANS=(`echo ${LISTCONTAINER[$CNT3]} | grep /qoslink: `)
      if [[ -n $ANS ]] ; then
        rm -f buffor_cfg.dat
        docker cp ${LISTCONTAINER[$CNT3+1]}:/buffor_cfg.dat buffor_cfg.dat   # Odczyt danych
        if [[ ! -e "buffor_cfg.dat" ]] ; then
          die 68 "Błąd w odczycie pliku konfiguracyjnego łącza"
        fi
        CFG2=(` awk 'BEGIN { RS = ":" } ; { print $0 }' buffor_cfg.dat `)
        for (( CNT4=0; CNT4<${#WSK[@]}; CNT4++ )) ; do
          if [[ "${CFG2[$CNT4]}" = "_" ]] ; then
            CFG2[$CNT4]=""
          fi
        done
        # Aktualizacja łącza pomiędzy dwoma podanymi urządzeniami w opcji -U dev1:dev2
        A0=(` echo ${CFG[20]} | grep ":" `)
        A1=(` echo ${CFG[20]} | awk -F: '{print $1}'`)
        A2=(` echo ${CFG[20]} | awk -F: '{print $2}'`)
        if [[ -n $ANS ]] ; then
          if [[ "$A1" = "${CFG2[1]}" || "$A1" = "${CFG2[2]}" || "$A1" = "${CFG2[16]}" || "$A1" = "${CFG2[17]}" || "$A1" = "${CFG2[18]}" || "$A1" = "${CFG2[19]}" || "$A1" = "${CFG2[32]}" || "$A1" = "${CFG2[33]}" ]] ; then
            if [[ "$A2" = "${CFG2[1]}" || "$A2" = "${CFG2[2]}" || "$A2" = "${CFG2[16]}" || "$A2" = "${CFG2[17]}" || "$A2" = "${CFG2[18]}" || "$A2" = "${CFG2[19]}" || "$A2" = "${CFG2[32]}" || "$A2" = "${CFG2[33]}" ]] ; then
              STAT2="dev1:dev2"
            fi
          fi  
        fi
        if [[ "${CFG[20]}" = "${CFG2[5]}" || "${CFG[20]}" = "${CFG2[6]}" || "${CFG[20]}" = "allupgrade" || "$STAT2" = "dev1:dev2" ]] ; then
          msg "${Y}Przed zmianą:${BCK}"
          read_dsp_cnt ${CFG2[0]}
          msg "${Y}Po zmianie:${BCK}"
          upgrade_link ${CFG2[0]}
          STAT3="tak"		#  Wykonano aktualizację
          STAT2=""		#  Zerowanie znacznika STAT2, zapobiega aktualizacji
        fi        		#  kolejnych przypadkowwych kontenerów.
      fi
    done
  fi
  if [[ "$STAT3" = "tak" ]] ; then
    msg "Gotowe."
  else
    msg "${R}Brak kontenera/ów do aktualizacji ${BCK}"
    exit 0
  fi
}

read_dsp_cnt() {
  msg ""
  rm -f buffor_cfg.dat		
  docker cp $1:/buffor_cfg.dat buffor_cfg.dat	# Odczyt danych
  if [[ ! -e "buffor_cfg.dat" ]] ; then
    die 63 "Podany kontener nie jest typu <qoslink>, nie zawiera informacji o stanie łącza"
  fi
  CFG2=(` awk 'BEGIN { RS = ":" } ; { print $0 }' buffor_cfg.dat `)
  for (( CNT=0; CNT<${#WSK[@]}; CNT++ )) ; do
    if [[ "${CFG2[$CNT]}" = "_" ]] ; then
      CFG2[$CNT]=""
    fi
    #echo "CFG2[$CNT]=${CFG2[$CNT]}"
  done
          # Ustalenie rodzaju połączenia
  if [[ -n ${CFG2[1]} ]] ; then
    TYPESIDE1="host"
    DEVSIDE1="-h1:${GB}${CFG2[1]}${BCK}"
  fi
  if [[ -n ${CFG2[16]} ]] ; then
    TYPESIDE1="switch"
    DEVSIDE1="-sw1:${GB}${CFG2[16]}${BCK}"
    CFG2[3]="${BLK}----${BCK}"
    CFG2[5]="${BLK}---------------${BCK}"
  fi
  if [[ -n ${CFG2[18]} ]] ; then
    TYPESIDE1="router"
    DEVSIDE1="-r1:${GB}${CFG2[18]}${BCK}"
  fi
  if [[ -n ${CFG2[32]} ]] ; then
    TYPESIDE1="phlink"
    DEVSIDE1="-ph1:${GB}${CFG2[32]}${BCK}"
  fi
  if [[ -n ${CFG2[2]} ]] ; then
    TYPESIDE2="host"
    DEVSIDE2="-h2:${GB}${CFG2[2]}${BCK}"
  fi
  if [[ -n ${CFG2[17]} ]] ; then
    TYPESIDE2="switch"
    DEVSIDE2="-sw2:${GB}${CFG2[17]}${BCK}"
    CFG2[4]="${BLK}----${BCK}"
    CFG2[6]="${BLK}---------------${BCK}"
  fi
  if [[ -n ${CFG2[19]} ]] ; then
    TYPESIDE2="router"
    DEVSIDE2="-r2:${GB}${CFG2[19]}${BCK}"
  fi
  if [[ -n ${CFG2[33]} ]] ; then
    TYPESIDE2="phlink"
    DEVSIDE2="-ph2:${GB}${CFG2[33]}${BCK}"
  fi
  if [[ -z ${CFG2[30]} ]] ; then
    CFG2[30]="${BLK}--------------${BCK}"
  fi
  if [[ -z ${CFG2[31]} ]] ; then
    CFG2[31]="${BLK}--------------${BCK}"
  fi
  M=(`echo ${CFG2[23]} | awk -F/ '{print $2}' `)	# odczyt adresu sieci na podstawie IP qoslink'a
  N=(` ipcalc ${CFG2[23]} -n | awk -F= '{print $2}' | awk -F. '{print $1,$2,$3,$4}' `)
  NM="${N[0]}.${N[1]}.${N[2]}.${N[3]}/$M"
  #msg "Połączenie pomiędzy ${DEVSIDE1} a ${DEVSIDE2}" 
  msg "${TYPESIDE1} \t\t\t \t\t \t\t\t ${TYPESIDE2}"
  msg "${DEVSIDE1} \t\t\t -c:${Y}${CFG2[0]}${BCK} \t\t\t ${DEVSIDE2}" 
  msg "-if1:${CFG2[3]} \t\t\t -link:${CFG2[15]} \t\t\t -if2:${CFG2[4]}"
  msg "-ip1:${GB}${CFG2[5]}${BCK} \t\t -ip3:${CFG2[23]} \t\t -ip2:${GB}${CFG2[6]}${BCK}"
  msg "-gw1:${CFG2[30]} \t\tnetwork ${NM}\t\t -gw2:${CFG2[31]}"
#  msg "-gw1:${CFG2[30]} \t\t \t\t \t\t -gw2:${CFG2[31]}"
  msg "\t-band1  \t\t${G}${CFG2[9]}${BCK}\t-->\t<--  ${G}${CFG2[10]}${BCK}\t-band2"
  msg "\t-loss1  \t\t${G}${CFG2[11]}${BCK}\t-->\t<--  ${G}${CFG2[12]}${BCK}\t-loss2"
  msg "\t-delay1 \t${G}${CFG2[13]}${BCK}\t-->\t<--  ${G}${CFG2[14]}${BCK}\t-delay2"
  msg "\t-duplic1\t${G}${CFG2[28]}${BCK}\t-->\t<--  ${G}${CFG2[29]}${BCK}\t-duplic2"
  msg ""
  msg "Sumaryczne:"
  msg "\t\t\t-band\t${G}${CFG2[34]}${BCK}"
  msg "\t\t\t-loss\t${G}${CFG2[35]}${BCK}"
  msg "\t\t\t-delay\t${G}${CFG2[36]}${BCK}"
  msg "\t\t\t-duplic\t${G}${CFG2[37]}${BCK}"
  msg "----------------------------------------------------------------------------"
}

prn_container() {
  ANS=(`docker ps -a | grep " ${CFG[38]} " `)
  if [[ -n $ANS ]] ; then
    CONTAINERLINK=(` docker inspect ${CFG[38]} | grep /qoslink: `)
    CONTAINERRUN=(` docker inspect ${CFG[38]} | grep -E "Running.*true" `)
    if [[ ! -n $CONTAINERRUN ]] ; then	# Kontener zatrzyman
      die 61 "Podany kontener <${CFG[38]}> jest zatrzymany"

    elif [[ -n $CONTAINERLINK ]] ; then	# Kontener typu qoslink
      read_dsp_cnt ${CFG[38]}

    else
      die 62 "Podany kontener ${CFG[38]} nie zawiera informacji o parametrach łącza"
    fi
  else
    # ---   Wyświetlanie po adresie IP
    LISTCONTAINER=(`docker ps -a | sed -n -e '1!p' | awk '{ print $2,$(NF) }' `)
    let CNTMAX=${#LISTCONTAINER[@]*2}
    for (( CNT3=0; CNT3<$CNTMAX; CNT3=CNT3+2 )) ; do
      ANS=(`echo ${LISTCONTAINER[$CNT3]} | grep /qoslink: `)
      if [[ -n $ANS ]] ; then
        rm -f buffor_cfg.dat
        docker cp ${LISTCONTAINER[$CNT3+1]}:/buffor_cfg.dat buffor_cfg.dat   # Odczyt danych
        if [[ ! -e "buffor_cfg.dat" ]] ; then
          die 68 "Błąd w odczycie pliku konfiguracyjnego łącza"
        fi
        CFG2=(` awk 'BEGIN { RS = ":" } ; { print $0 }' buffor_cfg.dat `)
        for (( CNT4=0; CNT4<${#WSK[@]}; CNT4++ )) ; do
          if [[ "${CFG2[$CNT4]}" = "_" ]] ; then
            CFG2[$CNT4]=""
          fi
        done
        A0=(` echo ${CFG[38]} | grep ":" `)
        A1=(` echo ${CFG[38]} | awk -F: '{print $1}'`)
        A2=(` echo ${CFG[38]} | awk -F: '{print $2}'`)
        if [[ -n $A0 ]] ; then
          # Wyświetlenie łącza pomiędzy dwoma podanymi urządzeniami w opcji -U dev1:dev2
          if [[ "$A1" = "${CFG2[1]}" || "$A1" = "${CFG2[2]}" || "$A1" = "${CFG2[16]}" || "$A1" = "${CFG2[17]}" || "$A1" = "${CFG2[18]}" || "$A1" = "${CFG2[19]}" || "$A1" = "${CFG2[32]}" || "$A1" = "${CFG2[33]}" ]] ; then
            if [[ "$A2" = "${CFG2[1]}" || "$A2" = "${CFG2[2]}" || "$A2" = "${CFG2[16]}" || "$A2" = "${CFG2[17]}" || "$A2" = "${CFG2[18]}" || "$A2" = "${CFG2[19]}" || "$A2" = "${CFG2[32]}" || "$A2" = "${CFG2[33]}" ]] ; then
              read_dsp_cnt ${CFG2[0]}
              STAT3="tak"   
              read temp  
            fi
          fi
        else
          if parseip ${CFG[38]} ; then
	    # Wyświetlenie po adresie IP
            if [[ "${CFG[38]}" = "${CFG2[5]}" || "${CFG[38]}" = "${CFG2[6]}" ]] ; then
              read_dsp_cnt ${CFG2[0]}
              STAT3="tak"     
              read temp  
            fi
          else
	    # Wyświetlenie po nazwie urządzenia (host, switch, router)
            # Zmienna DEVICE - lista urządzeń w danym łączu
            DEVICE=(` echo ${CFG2[1]}_${CFG2[2]}_${CFG2[16]}_${CFG2[17]}_${CFG2[18]}_${CFG2[19]}_${CFG2[32]}_${CFG2[33]} `)
            ANS=(` echo $DEVICE | grep "${CFG[38]}" `)  
            if [[ -n $ANS ]] ; then
              read_dsp_cnt ${CFG2[0]}
              STAT3="tak"     
              read temp  
            fi
          fi 
        fi
      fi
    done
  fi
  if [[ "$STAT3" = "tak" ]] ; then # STAT=tak => Były dane do wyświetlenia
    msg "Gotowe."
  else
    msg "${Y}Brak kontenera/ów do wyświetlenia ${BCK}"
    exit 0
  fi
}

prn_allcontainer() {
  LISTCONTAINER=(`docker ps -a | sed -n -e '1!p' | awk '{ print $2,$(NF) }' `)
  let CNTMAX=${#LISTCONTAINER[@]*2}
  for (( i=0; i<$CNTMAX; i=i+2 )) ; do
    ANS=(`echo ${LISTCONTAINER[$i]} | grep /qoslink: `)
    if [[ -n $ANS ]] ; then
      read_dsp_cnt ${LISTCONTAINER[$i+1]}
    fi
  done

}

# ----- Usuwanie virtualnych interfejsów oraz mostów
# ----- utworzonych skryptem "pipework"
# ----- We - Nazwa kontenera
# -----------------------------------------------------------
#del_veth() {
#  PID=(`docker inspect $1 | grep \"Pid\"
#}

# ----- Kasowanie kontenerów 
# ----- Po nazwie kontenera Qoslink lub adresie IP interfejsu
# ------------------------------------------------------------
del_container() {
  ANS=(`docker ps -a | grep ${CFG[27]}`)
  if [[ -n $ANS ]] ; then
    # ---  Kasowanie po nazwie kontenera Qoslink
    CONTAINERLINK=(` docker inspect ${CFG[27]} | grep qoslink: `)
    CONTAINERQUAGGA=(` docker inspect ${CFG[27]} | grep quaggalink: `)
    CONTAINERHOST=(` docker inspect ${CFG[27]} | grep host: `)
       CONTAINERRUN=(` docker inspect ${CFG[27]} | grep -E "Running.*true" `)
    if [[ ! -n $CONTAINERRUN ]] ; then			# Kontener zatrzyman
      die 61 "Podany kontener <${CFG[27]}> jest zatrzymany"
    elif [[ -n $CONTAINERLINK ]] ; then			# Kasowanie qoslink
      msg "Usuwanie kontenera typu qoslink: "${G}${CFG[27]}${BCK}""
    elif [[ -n $CONTAINERQUAGGA ]] ; then		# Kasowanie routera
      msg "Usuwanie kontenera (routera) typu quaggalink: \"${G}${CFG[27]}${BCK}\""
    else [[ -n $CONTAINERHOST ]] 			# Kasowanie hosta
      msg "Usuwanie kontenera typu host: \"${G}${CFG[27]}${BCK}\""
    fi
#    del_veth "${CFG[27]}"
    ANS=(`docker stop -t 0 ${CFG[27]}`)
    ANS=(`docker rm ${CFG[27]}`) 
    msg "Gotowe."
    exit 0
  elif [[ "${CFG[27]}" = "ALL" ]] ; then
    LISTCONTAINER=(`docker ps -a | sed -n -e '1!p' | awk '{ print $2,$(NF) }' `)
    let CNTMAX=${#LISTCONTAINER[@]*2}
    for (( CNT3=0; CNT3<$CNTMAX; CNT3=CNT3+2 )) ; do
      ANS1=(`echo ${LISTCONTAINER[$CNT3]} | grep qoslink: `)
      ANS2=(`echo ${LISTCONTAINER[$CNT3]} | grep quaggalink: `)
      ANS3=(`echo ${LISTCONTAINER[$CNT3]} | grep host: `)
      if [[ -n $ANS1 || -n $ANS2 || -n $ANS3 ]] ; then
        msg "Usuwanie kontenera ${G}${LISTCONTAINER[$CNT3+1]}${BCK}"
        ANS=(`docker stop -t 0 ${LISTCONTAINER[$CNT3+1]}`)
        ANS=(`docker rm ${LISTCONTAINER[$CNT3+1]}`)
      fi
    done
    # Usuwanie bridgy z systemu dodanych przez skrypt 
    LISTBRIDGE=(`nmcli d | grep $BRPREFIX[[:digit:]] | awk '{ print $1 }' | sort`)
    for (( CNT=0; CNT<${#LISTBRIDGE[@]}; CNT++ )) ; do
     msg "Usuwanie bridga ${G}${LISTBRIDGE[$CNT]}${BCK}"
     ANS=(`ip link set ${LISTBRIDGE[$CNT]} down`) 
     ANS=(`brctl delbr ${LISTBRIDGE[$CNT]}`) 
    done
    LISTSWITCH=(`nmcli d | grep $SWPREFIX[[:digit:]] | awk '{ print $1 }' | sort`)
    for (( CNT=0; CNT<${#LISTSWITCH[@]}; CNT++ )) ; do
     msg "Usuwanie switcha ${G}${LISTSWITCH[$CNT]}${BCK}"
     ANS=(`ip link set ${LISTSWITCH[$CNT]} down`) 
     ANS=(`brctl delbr ${LISTSWITCH[$CNT]}`) 
    done
    msg "Gotowe"
    exit 0    
  else
    # ---   Kasowanie po adresie IP
    LISTCONTAINER=(`docker ps -a | sed -n -e '1!p' | awk '{ print $2,$(NF) }' `)
    let CNTMAX=${#LISTCONTAINER[@]*2}
    for (( CNT3=0; CNT3<$CNTMAX; CNT3=CNT3+2 )) ; do
      ANS=(`echo ${LISTCONTAINER[$CNT3]} | grep /qoslink: `)
      if [[ -n $ANS ]] ; then
        rm -f buffor_cfg.dat
        docker cp ${LISTCONTAINER[$CNT3+1]}:/buffor_cfg.dat buffor_cfg.dat   # Odczyt danych
        if [[ ! -e "buffor_cfg.dat" ]] ; then
          die 68 "Błąd w odczycie pliku konfiguracyjnego łącza"
        fi
        CFG2=(` awk 'BEGIN { RS = ":" } ; { print $0 }' buffor_cfg.dat `)
        for (( CNT4=0; CNT4<${#WSK[@]}; CNT4++ )) ; do
          if [[ "${CFG2[$CNT4]}" = "_" ]] ; then
            CFG2[$CNT4]=""
          fi
        done
        # Kasowanie łącza pomiędzy dwoma podanymi urządzeniami w opcji -D dev1:dev2
        A0=(` echo ${CFG[27]} | grep ":" `)
        A1=(` echo ${CFG[27]} | awk -F: '{print $1}'`)
        A2=(` echo ${CFG[27]} | awk -F: '{print $2}'`)
        if [[ -n $ANS ]] ; then
          if [[ "$A1" = "${CFG2[1]}" || "$A1" = "${CFG2[2]}" || "$A1" = "${CFG2[16]}" || "$A1" = "${CFG2[17]}" || "$A1" = "${CFG2[18]}" || "$A1" = "${CFG2[19]}" || "$A1" = "${CFG2[32]}" || "$A1" = "${CFG2[33]}" ]] ; then
            if [[ "$A2" = "${CFG2[1]}" || "$A2" = "${CFG2[2]}" || "$A2" = "${CFG2[16]}" || "$A2" = "${CFG2[17]}" || "$A2" = "${CFG2[18]}" || "$A2" = "${CFG2[19]}" || "$A2" = "${CFG2[32]}" || "$#A2" = "${CFG2[33]}" ]] ; then
              STAT2="dev1:dev2"
            fi
          fi  
        fi
        if [[ "${CFG[27]}" = "${CFG2[5]}" || "${CFG[27]}" = "${CFG2[6]}" || "${CFG[27]}" = "deldefaultnamecnt" || "$STAT2" = "dev1:dev2" ]] ; then
          msg "Usuwanie kontenera typu qoslink: "${G}${CFG2[0]}${BCK}""
          ANS=(`docker stop -t 0 ${CFG2[0]}`)
          ANS=(`docker rm ${CFG2[0]}`)
          STAT2=""
        fi        
      fi
    done
  fi
  msg "Gotowe"
  exit 0
}

# -----  Zapis parametrów  
# -----  We - Nazwa pliku
# ------------------------------------------------------------
save_container() {

  if [[ "${CFG[39]}" = "savedefaultname" ]] ; then
    LISTFILE=(`ls`)		
    PASS=0
    for (( CNT=0; CNT<$FILEMAX; CNT++ )) ; do
      ANS=(`echo ${LISTFILE[@]} | grep ${FILEPREFIX}${CNT}\.dat `)
      if [[ -z ${ANS[@]} ]] ; then 
        PASS=1
      fi
      if [[ $PASS -eq 1 ]] ; then 
        CFG[39]=${FILEPREFIX}${CNT}		# Wyszukana wolna nazwa pliku
        CNT=$FILEMAX
      fi
    done
    if [[ $PASS -eq 0 ]] ; then
      die 6 "Brak wolnych nazw plików"
    fi
  fi
  if [ -e "${CFG[39]}.dat" ] ; then
    msg "${Y}Istnieje już plik o nazwie ${G}${CFG[39]}.dat${BCK}"
    msg "${Y}Zostanie wykonany backup poprzedniej wersji jako ${G}${CFG[39]}.bck${BCK}"
    cp -f ${CFG[39]}.dat ${CFG[39]}.bck
    rm -f ${CFG[39]}.dat
  fi 

  LISTCONTAINER=(`docker ps -a | sed -n -e '1!p' | awk '{ print $2,$(NF) }' `)
  let CNTMAX=${#LISTCONTAINER[@]*2}
  STAT4=0		# Znacznik braku danych do zapisu
  CNT5=0  		# Liczba kontenerów qoslink do zapisu
  for (( CNT3=0; CNT3<$CNTMAX; CNT3=CNT3+2 )) ; do
    ANS=(`echo ${LISTCONTAINER[$CNT3]} | grep qoslink: `)
    if [[ -n $ANS ]] ; then
      rm -f buffor_cfg.dat		
      docker cp ${LISTCONTAINER[$CNT3+1]}:/buffor_cfg.dat buffor_cfg.dat	# Odczyt danych
      cat buffor_cfg.dat >> ${CFG[39]}.dat
      STAT4=1
      let CNT5=CNT5+1
    fi
  done
  if [[ $STAT4 -eq 0 ]] ; then
     msg "${Y}Brak danych do zapisu${BCK}"
  else
    if [[ $CNT5 -eq 1 ]] ; then
      msg "Zapis: ${G}$CNT5 węzła${BCK}"
    else
      msg "Zapis: ${G}$CNT5 węzłów${BCK}"
    fi
      msg "Nazwa pliku: ${G}${CFG[39]}.dat${BCK}"
  fi
  exit 0
}

load_container() {
  if [ ! -e ${CFG[40]}.dat ] ; then
    die 86 "Podany plik ${CFG[40]}.dat nie istnieje"
  fi 
  CFGALL=(`cat ${CFG[40]}.dat`)
  CFGALL2=(`echo ${CFGALL[@]} | awk -F'\n' '{print}' `)
  for (( CNT7=${#CFGALL[@]}; CNT7>0; CNT7-- )) ; do
    unset CFG
    CFG=(`echo ${CFGALL2[$CNT7-1]} | awk 'BEGIN { RS = ":" } ; { print $0 }' `)
    for (( CNT6=0; CNT6<${#WSK[@]}; CNT6++ )) ; do
      if [[ ${CFG[$CNT6]} == "_" ]] ; then
        CFG[$CNT6]=""
      fi
    done
    echo ".........................."
    # --- Określenie rodzaju połączenia
    # ---------------------------------
    KOD=0
    if [[ -n ${CFG[32]} ]] ; then
      let KOD=$KOD+128 ; fi
    if [[ -n ${CFG[33]} ]] ; then
      let KOD=$KOD+64  ; fi
    if [[ -n ${CFG[1]} ]] ; then
      let KOD=$KOD+32 ; fi
    if [[ -n ${CFG[2]} ]] ; then
      let KOD=$KOD+16  ; fi
    if [[ -n ${CFG[16]} ]] ; then
      let KOD=$KOD+8   ; fi
    if [[ -n ${CFG[17]} ]] ; then
      let KOD=$KOD+4   ; fi
    if [[ -n ${CFG[18]} ]] ; then
      let KOD=$KOD+2   ; fi
    if [[ -n ${CFG[19]} ]] ; then
      let KOD=$KOD+1   ; fi

    case "$KOD" in

48)                                             # h1  ---  h2
      crt_c
      set_h1
      crt_h1
      set_h2
      crt_h2
      crt_linkif1
      crt_linkif2
      crt_linkif3
      crt_linkif4
      crt_brinqos
      set_link
      ;;

36)                                            # h1  ---  sw2
      crt_c
      set_h1
      crt_h1
      crt_linkif1
      crt_linkif3
      crt_linkif4sw2
      crt_brinqos
      set_link
      ;;

33)                                            # h1  ---  r2
      crt_c
      set_h1
      crt_h1
      set_r2
      crt_r2
      crt_linkif1
      crt_linkif2r2
      crt_linkif3
      crt_linkif4
      crt_brinqos
      set_link
      ;;

24)                                             # sw1  ---  h2
      crt_c
      set_h2
      crt_h2
      crt_linkif2
      crt_linkif3sw1
      crt_linkif4
      crt_brinqos
      set_link
      ;;

12)                                             # sw1  ---  sw2
      crt_c
      crt_linkif3sw1
      crt_linkif4sw2
      crt_brinqos
      set_link
      ;;

9)                                             # sw1  ---  r2
      crt_c
      set_r2
      crt_r2
      crt_linkif2r2
      crt_linkif3sw1
      crt_linkif4
      crt_brinqos
      set_link
      ;;

18)                                            # r1  ---  h2
      crt_c
      set_h2
      crt_h2
      set_r1
      crt_r1
      crt_linkif1r1
      crt_linkif2
      crt_linkif3
      crt_linkif4
      crt_brinqos
      set_link
      ;;

6)                                             # r1  ---  sw2
      crt_c
      set_r1
      crt_r1
      crt_linkif1r1
      crt_linkif3
      crt_linkif4sw2
      crt_brinqos
      set_link
      ;;

3)                                             # r1  ---  r2
      crt_c
      set_r1
      crt_r1
      set_r2
      crt_r2
      crt_linkif1r1
      crt_linkif2r2
      crt_linkif3
      crt_linkif4
      crt_brinqos
      set_link
      ;;
 
72)						# sw1  ---  ph2
      crt_c
      set_ph2
      crt_ph2
      set_if2ph2
      crt_linkif2ph2
      crt_linkif3sw1
      crt_linkif4
      crt_brinqos
      set_link
      crt_linkif2docker0
      ;;    

66)						# r1  ---  ph2
      crt_c
      set_r1
      crt_r1
      set_ph2
      crt_ph2
      crt_linkif1r1
      crt_linkif2ph2
      crt_linkif3
      crt_linkif4
      crt_brinqos
      set_link
      crt_linkif2docker0
      ;;

132)						# ph1  ---  sw2
      crt_c
      set_ph1
      crt_ph1
      crt_linkif1ph1
      crt_linkif3
      crt_linkif4sw2
      crt_brinqos
      set_link
      crt_linkif1docker0
      ;;    

129)						# ph1  ---  r2
      crt_c
      set_ph1
      crt_ph1
      set_r2
      crt_r2
      crt_linkif1ph1
      crt_linkif2r2
      crt_linkif3
      crt_linkif4
      crt_brinqos
      set_link
      crt_linkif1docker0
      ;;
*)

      die 97 "Nieprawidłowe zestawienie parametrów przy odczycie"

    esac
		
  done
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
#   Tablica z dostępnymi opcjami i parametrami wejściowymi dla skryptu
#   | 0 | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9    | 10   | 11   | 12   | 13    | 14    | 15  | 16 | 17 | 18 | 19 | 20 | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28     | 29     | 30 | 31 | 32 | 33 | 34  | 35  | 36   | 37    | 38 | 39 | 40 )
WSK=(-c  -h1  -h2  -if1 -if2 -ip1 -ip2 -br1 -br2 -band1 -band2 -loss1 -loss2 -delay1 -delay2 -link -sw1 -sw2 -r1  -r2  -U   -v   -V   -ip3 -ip4 -if3 -if4 -D   -duplic1 -duplic2 -gw1 -gw2 -ph1 -ph2 -band -loss -delay -duplic -P   -S   -L )

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
  STAT=0				# Znacznik zatrzymujący sort w przypadku nieznanej opcji
  for (( CNT2=0; CNT2<${#WSK[@]}; CNT2++ )) ; do 
    if [ ${PARAM[$CNT]} = ${WSK[$CNT2]} ] ; then
      STAT=1
      CFG[$CNT2]=${PARAM[$CNT+1]}
      CFGNEXT=${CFG[$CNT2]}		# Pierwszy znak następnego parametru 
      CFGNEXT=${CFGNEXT:0:1}		# "-" lub pusty ciąg oznacza brak argumentu 
					# w bieżacym parametrze (np. -sw1 -h2 serwer

      if [ ${PARAM[$CNT]} = "-h1" ] ; then		# Wtymusza automatyczną nazwę hosta
        if [[ -n ${CFG[$CNT2]} ]] ; then
          if [[ "$CFGNEXT" = "-" ]] ; then
            CFG[$CNT2]="setnamecnthost"
          fi
        else
          CFG[$CNT2]="setnamecnthost"
        fi
      fi

      if [ ${PARAM[$CNT]} = "-h2" ] ; then		# Wymusza  automatyczną nazwę hosta
        if [[ -n ${CFG[$CNT2]} ]] ; then
          if [[ "$CFGNEXT" = "-" ]] ; then
            CFG[$CNT2]="setnamecnthost"
          fi
        else
          CFG[$CNT2]="setnamecnthost"
        fi
      fi

      if [ ${PARAM[$CNT]} = "-r1" ] ; then		# Wymusza automatyczną nazwę routera
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

      if [ ${PARAM[$CNT]} = "-ph1" ] ; then		# Wymusza automatyczną nazwę łącza phlink
        if [[ -n ${CFG[$CNT2]} ]] ; then
          if [[ "$CFGNEXT" = "-" ]] ; then
            CFG[$CNT2]="setnamecntph"
          fi
        else
          CFG[$CNT2]="setnamecntph"
        fi
      fi

      if [ ${PARAM[$CNT]} = "-ph2" ] ; then		# Wymusza  automatyczną nazwę łącza phlink
        if [[ -n ${CFG[$CNT2]} ]] ; then
          if [[ "$CFGNEXT" = "-" ]] ; then
            CFG[$CNT2]="setnamecntph"
          fi
        else
          CFG[$CNT2]="setnamecntph"
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
          if [[ "$CFGNEXT" = "-" ]] ; then
            CFG[$CNT2]="deldefaultnamecnt"
          fi
        else
          CFG[$CNT2]="deldefaultnamecnt"
        fi
      fi

      if [ ${PARAM[$CNT]} = "-P" ] ; then		# Wyświetlenie parametrów wszystkich
        if [[ -n ${CFG[$CNT2]} ]] ; then		# lub wybranego kontenera
          if [[ "$CFGNEXT" = "-" ]] ; then
            CFG[$CNT2]="printallcnt"
          fi
        else
          CFG[$CNT2]="printallcnt"
        fi
      fi

      if [ ${PARAM[$CNT]} = "-U" ] ; then		# Upgrade wszystkich
        if [[ -n ${CFG[$CNT2]} ]] ; then		# lub wybranego kontenera
          if [[ "$CFGNEXT" = "-" ]] ; then
            CFG[$CNT2]="allupgrade"
          fi
        else
          CFG[$CNT2]="allupgrade"
        fi
      fi

      if [ ${PARAM[$CNT]} = "-S" ] ; then		# Zapis parametrów sieci
        if [[ -n ${CFG[$CNT2]} ]] ; then		
          if [[ "$CFGNEXT" = "-" ]] ; then
            CFG[$CNT2]="savedefaultname"
          fi
        else
          CFG[$CNT2]="savedefaultname"
        fi
      fi

      if [ ${PARAM[$CNT]} = "-L" ] ; then		# Odczyt parametrów sieci
        if [[ -n ${CFG[$CNT2]} ]] ; then		
          if [[ "$CFGNEXT" = "-" ]] ; then
            CFG[$CNT2]="noname"
          fi
        else
          CFG[$CNT2]="noname"
        fi
      fi

      if [ ${PARAM[$CNT]} = "-v" ] ; then		# Wyswietlanie komunikatow
        CFG[$CNT2]=0
      fi

      if [ ${PARAM[$CNT]} = "-V" ] ; then		# Wyswietlanie komunikatow debugowania
        CFG[$CNT2]=0
      fi

    fi
  done
  CFGIT=${PARAM[$CNT]}	# Weryfikacja poprawności nazwy opcji
  CFGIT=${CFGIT:0:1}	# Jeżeli jest z "-" i nie ma w tablicy WSK[] => błąd	
  if [[ "$STAT" = "0" && "$CFGIT" = "-" ]] ; then
    die 69 "Podano nieprawidłową opcję : ${PARAM[$CNT]}"
  fi
done

# Sprawdzenie i ewentualne utworzenie obrazów kontenerów Quaggalink i Qoslink
# ---------------------------------------------------------------------------
chk_crt_img_qoslink
chk_crt_img_quaggalink

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
  CFG[11]="0.01%"
else
  if [[ -n ${CFG[11]} ]] ; then
    chk_loss 11
  fi
fi

# ----  Weryfikacja parametru utraty pakietów - LOSS2
if [[ -z ${CFG[12]} && ! ${CFG[20]} ]] ; then
  CFG[12]="0.01%"
else
  if [[ -n ${CFG[12]} ]] ; then
    chk_loss 12
  fi
fi

# ----  Weryfikacja parametru opóżnienia - DELAY1
if [[ -z ${CFG[13]} && ! ${CFG[20]} ]] ; then
  CFG[13]="0.12ms"
else
  if [[ -n ${CFG[13]} ]] ; then
    chk_delay 13
  fi
fi

# ----  Weryfikacja parametru opóżnienia - DELAY2
if [[ -z ${CFG[14]} && ! ${CFG[20]} ]] ; then
  CFG[14]="0.12ms"
else
  if [[ -n ${CFG[14]} ]] ; then
    chk_delay 14
  fi
fi

# ----  Weryfikacja parametru duplicowania - DUPLIC1
if [[ -z ${CFG[28]} && ! ${CFG[20]} ]] ; then
  CFG[28]="0.01%"
else
  if [[ -n ${CFG[28]} ]] ; then
    chk_duplic 28
  fi
fi

# ----  Weryfikacja parametru duplicowania - DUPLIC2
if [[ -z ${CFG[29]} && ! ${CFG[20]} ]] ; then
  CFG[29]="0.01%"
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
    CFG[15]="."
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
    CFG[15]="." 
  fi
  if [[ -n $ANS2 ]] ; then	# Podawan3 wg ilości pakietów
    let LOSS=${CFG[35]}/2
    CFG[11]=${LOSS}
    CFG[12]=${LOSS}
    CFG[15]="." 
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
  CFG[15]="." 
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
    CFG[15]="." 
  fi
  if [[ -n $ANS2 ]] ; then
    let DUPLIC=${CFG[37]}/2
    CFG[28]=${DUPLIC}
    CFG[29]=${DUPLIC}
    CFG[15]="." 
  fi
fi

# ----- Weryfikacja nazwy łącza  -link
# ----- Gdy poprawne, aktualizuje poszczgólne parametry łącza
# -----------------------------------------
if [[ -n ${CFG[15]} ]] ; then
  checklink ${CFG[15]}
fi

# -----  Aktualizacja parametrów łącza QOSLINK 
# ----- Po nazwie kontenera Qoslink lub adresie IP interfejsu
# ------------------------------------------------------------
if [[ -n ${CFG[20]} ]] ; then			# Wybrana funkcja aktualizacji
  upgrade_container
  exit 0
fi

# ----  Wyświetlenie parametrów łącza <qoslink>
if [[ -n ${CFG[38]} ]] ; then
  CFG[21]="0"			# włącza wyświetlanie komunikatów pomimo  braku opcji -v
  if [[ "${CFG[38]}" = "printallcnt" ]] ; then	
    prn_allcontainer
  else
    prn_container "${CFG[38]}"
  fi
  exit 0
fi

# ----  Usuwanie kontenerów
if [[ -n ${CFG[27]} ]] ; then
  del_container
  exit 0
fi

# ----  Zapis parametrów sieci
if [[ -n ${CFG[39]} ]] ; then
  save_container
  exit 0
fi

# ----  Odczyt parametrów sieci
if [[ -n ${CFG[40]} ]] ; then
  load_container
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
  if checkinterface "${CFG[25]}" "${CFG[0]}" ; then
    die 5 "Nazwa interfejsu z opcji -if3 ${CFG[25]} jest już utworzona w kontenerze ${CFG[0]}"
  fi
fi

# -----  Weryfikacja interfejsu  IF4  -----
if [[ -n ${CFG[26]} ]] ; then
  if checkinterface "${CFG[26]}" "${CFG[0]}" ; then
    die 5 "Nazwa interfejsu z opcji -if4 ${CFG[26]} jest już utworzona w kontenerze ${CFG[0]}"
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

# Podgląd tablicy z parametrami
# ---------------------
#for (( CNT=0; CNT<${#WSK[@]}; CNT++ )) ; do
#  echo "CFG[$CNT] -eq ${CFG[$CNT]} " 
#done

# ------  Określenie rodzaju polaczenia (Host-Host, Host-Switch, Host-Router, Switch-Router, itp)
# -----------------------------------------------------------------------------------------------

KOD=0
if [[ -n ${CFG[32]} ]] ; then
  let KOD=$KOD+512 ; fi
if [[ -n ${CFG[33]} ]] ; then 
  let KOD=$KOD+256  ; fi
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
    set_h2
    crt_h2
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
    set_h1
    crt_h1
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
    set_h2
    crt_h2
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
    set_h1
    crt_h1
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
    set_h1
    crt_h1
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
    set_h1
    crt_h1
    set_h2
    crt_h2
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
    set_h1
    crt_h1
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
    set_h2
    crt_h2
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
    set_h1
    crt_h1
    set_h2
    crt_h2
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

82)						# r1          ---  h2 + ip2
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
    set_h2
    crt_h2
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

98)						# r1 + ip1  ---         h2
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
    set_h2
    crt_h2
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


35)						# ri + ip1  ---         r2
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

145)						# h1        ---         r2 + ip2
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
    set_h1
    crt_h1
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


19)						# r1       ---  r2 + ip2
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


177)						# h1 + ip1  ---  r2 + ip2  
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
      set_h1
      crt_h1
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
      set_h1
      crt_h1
      set_h2
      crt_h2
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
      set_h2
      crt_h2
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



51)						# r1 + ip1  ---  r2 + ip2  
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

192)                                            # h1        ---  h2
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
    set_h1
    crt_h1
    set_h2
    crt_h2
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

3)						# r1        ---  r2
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

264)						# sw1       ---  ph2
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
    set_ph2
    crt_ph2
    set_if2ph2
    crt_linkif2ph2
    set_if3
    crt_linkif3sw1
    set_if4
    crt_linkif4
    crt_brinqos
    set_link
    crt_linkif2docker0
    ;;    

280)						# sw1       ---  ph2 + ip2
    checkipall ${CFG[6]}
    freeip ${CFG[6]}
    CFG[23]=$NEWIP
    freeip ${CFG[6]}
    CFG[24]=$NEWIP
    set_c
    set_sw1
    set_br2
    crt_c
    set_ph2
    crt_ph2
    set_if2ph2
    crt_linkif2ph2
    set_if3
    crt_linkif3sw1
    set_if4
    crt_linkif4
    crt_brinqos
    set_link
    crt_linkif2docker0
    ;;    

258)						# r1       ---  ph2
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
    set_ph2
    crt_ph2
    set_if1r1
    crt_linkif1r1
    set_if2ph2
    crt_linkif2ph2
    set_if3
    crt_linkif3
    set_if4
    crt_linkif4
    crt_brinqos
    set_link
    crt_linkif2docker0
    ;;

290)						# r1 + ip1  ---         ph2
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
    set_ph2
    crt_ph2
    set_if1r1
    crt_linkif1r1
    set_if2ph2
    crt_linkif2ph2
    set_if3
    crt_linkif3
    set_if4
    crt_linkif4
    crt_brinqos
    set_link
    crt_linkif2docker0
    ;;

274)						# r1       ---  ph2 + ip2
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
    set_ph2
    crt_ph2
    set_if1r1
    crt_linkif1r1
    set_if2ph2
    crt_linkif2ph2
    set_if3
    crt_linkif3
    set_if4
    crt_linkif4
    crt_brinqos
    set_link
    crt_linkif2docker0
    ;;

306)						# r1 + ip1  ---  ph2 + ip2  
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
      set_ph2
      crt_ph2
      set_if1r1
      crt_linkif1r1
      set_if2ph2
      crt_linkif2ph2
      set_if3
      crt_linkif3
      set_if4
      crt_linkif4
      crt_brinqos
      set_link
      crt_linkif2docker0
    else     
      exit 0
    fi
    ;;

516)						# ph1       ---  sw2
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
    set_ph1
    crt_ph1
    set_if1ph1
    crt_linkif1ph1
    set_if3
    crt_linkif3
    set_if4
    crt_linkif4sw2
    crt_brinqos
    set_link
    crt_linkif1docker0
    ;;    

548)						# ph1 + ip1  ---       sw2
    checkipall ${CFG[5]}
    freeip ${CFG[5]}
    CFG[23]=$NEWIP
    freeip ${CFG[5]}
    CFG[24]=$NEWIP
    set_c
    set_br1
    set_sw2
    crt_c
    set_ph1
    crt_ph1
    set_if1ph1
    crt_linkif1ph1
    set_if3
    crt_linkif3
    set_if4
    crt_linkif4sw2
    crt_brinqos
    set_link 
    crt_linkif1docker0
    ;;

513)						# ph1       ---  r2
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
    set_ph1
    crt_ph1
    set_r2
    crt_r2
    set_if1ph1
    crt_linkif1ph1
    set_if2r2
    crt_linkif2r2
    set_if3
    crt_linkif3
    set_if4
    crt_linkif4
    crt_brinqos
    set_link
    crt_linkif1docker0
    ;;

545)						# ph1 + ip1  ---         r2
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
    set_ph1
    crt_ph1
    set_r2
    crt_r2
    set_if1ph1
    crt_linkif1ph1
    set_if2r2
    crt_linkif2r2
    set_if3
    crt_linkif3
    set_if4
    crt_linkif4
    crt_brinqos
    set_link
    crt_linkif1docker0
    ;;

19)						# ph1       ---  r2 + ip2
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
    set_ph1
    crt_ph1
    set_r2
    crt_r2
    set_if1ph1
    crt_linkif1ph1
    set_if2r2
    crt_linkif2r2
    set_if3
    crt_linkif3
    set_if4
    crt_linkif4
    crt_brinqos
    set_link
    crt_linkif1docker0
    ;;

51)						# ph1 + ip1  ---  r2 + ip2  
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
      set_ph1
      crt_ph1
      set_r2
      crt_r2
      set_if1ph1
      crt_linkif1ph1
      set_if2r2
      crt_linkif2r2
      set_if3
      crt_linkif3
      set_if4
      crt_linkif4
      crt_brinqos
      set_link
      crt_linkif1docker0
    else     
      exit 0
    fi
    ;;
*)
    die 80 "${R}Nieprawidłowe zestawienie parametrów.${BCK}"    
esac

msg "Gotowe"
exit 0
