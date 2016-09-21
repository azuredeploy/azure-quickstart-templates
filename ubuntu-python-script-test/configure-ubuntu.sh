#!/bin/bash

sudo apt-get update
# install jdk
wget --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u101-b13/jdk-8u101-linux-x64.tar.gz
sudo tar -xzf -C /opt
sudo ln -s /opt/jdk1.8.0_101 /opt/jdk
sudo update-alternatives --install /usr/bin/java java /opt/jdk/bin/java 100
sudo update-alternatives --install /usr/bin/javac javac /opt/jdk/bin/javac 100
# install activemq
wget https://www.dropbox.com/s/2vwr0o4gv2xr1oc/apache-activemq-5.14.0-bin.tar.gz
sudo tar -xzf -C /opt
sudo ln -s /opt/apache-activemq-5.14.0 /opt/amq
# configure the machine
sudo python configureserver.py
