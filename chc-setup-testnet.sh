#/bin/bash

cd ~
echo "****************************************************************************"
echo "* Ubuntu 17.10 is the recommended opearting system for this install.       *"
echo "*                                                                          *"
echo "* This script will install and configure your Chaincoin (.16 Testnet) masternodes.  *"
echo "****************************************************************************"
echo && echo && echo
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!                                                 !"
echo "! Make sure you double check before hitting enter !"
echo "!                                                 !"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo && echo && echo

echo "Do you want to install all needed dependencies (no if you did it before)? [y/n]"
read DOSETUP

if [[ $DOSETUP =~ "y" ]] ; then
  sudo apt-get update
  sudo apt-get install -y build-essential libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils python3 git
  sudo apt-get install -y libboost-system-dev libboost-filesystem-dev libboost-chrono-dev libboost-program-options-dev libboost-test-dev libboost-thread-dev
  sudo apt-get install -y libminiupnpc-dev
  sudo apt-get install -y libzmq3-dev
  sudo apt-get install -y libqt5gui5 libqt5core5a libqt5dbus5 qttools5-dev qttools5-dev-tools libprotobuf-dev protobuf-compiler
  sudo apt-get install -y libqrencode-dev


  cd /var
  sudo touch swap.img
  sudo chmod 600 swap.img
  sudo dd if=/dev/zero of=/var/swap.img bs=1024k count=2000
  sudo mkswap /var/swap.img
  sudo swapon /var/swap.img
  sudo free
  sudo echo "/var/swap.img none swap sw 0 0" >> /etc/fstab
  cd

  git clone https://github.com/ChainCoin/chaincoin.git -b Chaincoin_0.16-dev
  cd chaincoin
  ./autogen.sh
  sudo ./contrib/install_db4.sh berkeley48
  export BDB_PREFIX='/db4'
  ./configure CPPFLAGS="-I${BDB_PREFIX}/include/ -O2 -fPIC" LDFLAGS="-L${BDB_PREFIX}/lib/" ./configure CXXFLAGS="--param ggc-min-expand=1 --param ggc-min-heapsize=32768" --disable-zmq --disable-tests --enable-debug
  sudo make


  sudo apt-get install -y ufw
  sudo ufw allow ssh/tcp
  sudo ufw limit ssh/tcp
  sudo ufw logging on
  echo "y" | sudo ufw enable
  sudo ufw status

  mkdir -p ~/bin
  echo 'export PATH=~/bin:$PATH' > ~/.bash_aliases
  source ~/.bashrc
fi

## Setup conf
mkdir -p ~/bin
echo ""
echo "Configure your masternodes now!"
echo "Type the IP of this server, followed by [ENTER]:"
read IP

MNCOUNT=""
re='^[0-9]+$'
while ! [[ $MNCOUNT =~ $re ]] ; do
   echo ""
   echo "How many nodes do you want to create on this server?, followed by [ENTER]:"
   read MNCOUNT
done

for i in `seq 1 1 $MNCOUNT`; do
  echo ""
  echo "Enter alias for new node"
  read ALIAS

  echo ""
  echo "Enter port for node $ALIAS(i.E. 21994)"
  read PORT

  echo ""
  echo "Enter masternode private key for node $ALIAS"
  read PRIVKEY

  echo ""
  echo "Enter RPC Port (Any valid free port: i.E. 21995)"
  read RPCPORT

  ALIAS=${ALIAS,,}
  CONF_DIR=~/.chaincoin_$ALIAS

  # Create scripts
  echo '#!/bin/bash' > ~/bin/chaincoind_$ALIAS.sh
  echo "chaincoind -daemon -conf=$CONF_DIR/chaincoin.conf -datadir=$CONF_DIR "'$*' >> ~/bin/chaincoind_$ALIAS.sh
  echo '#!/bin/bash' > ~/bin/chaincoin-cli_$ALIAS.sh
  echo "chaincoin-cli -conf=$CONF_DIR/chaincoin.conf -datadir=$CONF_DIR "'$*' >> ~/bin/chaincoin-cli_$ALIAS.sh
  echo '#!/bin/bash' > ~/bin/chaincoin-tx_$ALIAS.sh
  echo "chaincoin-tx -conf=$CONF_DIR/chaincoin.conf -datadir=$CONF_DIR "'$*' >> ~/bin/chaincoin-tx_$ALIAS.sh
  chmod 755 ~/bin/chaincoin*.sh

  mkdir -p $CONF_DIR
  echo "testnet=1" >> chaincoin.conf_TEMP
  echo "rpcuser=user"`shuf -i 100000-10000000 -n 1` >> chaincoin.conf_TEMP
  echo "rpcpassword=pass"`shuf -i 100000-10000000 -n 1` >> chaincoin.conf_TEMP
  echo "rpcallowip=127.0.0.1" >> chaincoin.conf_TEMP
  echo "rpcport=$RPCPORT" >> chaincoin.conf_TEMP
  echo "listen=1" >> chaincoin.conf_TEMP
  echo "server=1" >> chaincoin.conf_TEMP
  echo "daemon=1" >> chaincoin.conf_TEMP
  echo "logtimestamps=1" >> chaincoin.conf_TEMP
  echo "maxconnections=256" >> chaincoin.conf_TEMP
  echo "masternode=1" >> chaincoin.conf_TEMP
  echo "" >> chaincoin.conf_TEMP

  echo "addnode=addnode=45.79.216.13" >> chaincoin.conf_TEMP
  echo "addnode=144.202.39.195" >> chaincoin.conf_TEMP

  echo "" >> chaincoin.conf_TEMP
  echo "port=$PORT" >> chaincoin.conf_TEMP
  echo "externalip=$IP" >> chaincoin.conf_TEMP
  echo "bind=$IP" >> chaincoin.conf_TEMP
  echo "masternodeaddr=$IP:$PORT" >> chaincoin.conf_TEMP
  echo "masternodeprivkey=$PRIVKEY" >> chaincoin.conf_TEMP
  sudo ufw allow $PORT/tcp

  mv chaincoin.conf_TEMP $CONF_DIR/chaincoin.conf

  sh ~/bin/chaincoind_$ALIAS.sh
done
