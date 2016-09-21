#!/bin/bash

sudo apt-get update
# install jdk
wget --header "Cookie: oraclelicense=accept-securebackup-cookie" $5
sudo tar -xzf -C /opt
sudo ln -s /opt/jdk1.8.0_101 /opt/jdk
sudo update-alternatives --install /usr/bin/java java /opt/jdk/bin/java 100
sudo update-alternatives --install /usr/bin/javac javac /opt/jdk/bin/javac 100
# install activemq
wget $6
sudo tar -xzf -C /opt
sudo ln -s /opt/apache-activemq-5.14.0 /opt/amq
# configure the machine
sudo python configureserver.py
