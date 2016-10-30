#!/bin/bash




mylog()
{
    # If you want to enable this logging add a un-comment the line below and add your account id
    curl -X POST -H "content-type:text/plain" --data-binary "${HOSTNAME} - $1" https://logs-01.loggly.com/inputs/72e878ca-1b43-4fb5-87ea-f78b6f378840/tag/AMQeWSO2,${HOSTNAME}
    logger "$1"
}


# You must be root to run this script
if [ "${UID}" -ne 0 ];
then
    log "Script executed without root permissions"
    echo "You must be root to run this program." >&2
    exit 3
fi

#Format the data disk
#D bash vm-disk-utils-0.1.sh -s   # ci devo mettere qalcosa per partizionare il disco
####   
#DATA_DISKS="/datadisks"
#DATA_MOUNTPOINT="$DATA_DISKS/disk1"
#COUCHBASE_DATA="$DATA_MOUNTPOINT/couchbase"
# Stripe all of the data disks
#bash ./vm-disk-utils-0.1.sh -b $DATA_DISKS -s


#### Defalt Paramenters ####

#Define Mysql Password

# Configure java parameters
export GET_JAVA_SITE="http://javadl.oracle.com/webapps/download/AutoDL?BundleId=211989"
export GET_JAVA_FILE="jre-8u101-linux-x64.tar.gz"
export JAVA_TMP_PATH="/opt/jre1.8.0_101"

#  Configure ActiveMQ parameters
export GET_ACTIVEMQ_SITE="https://www.dropbox.com/s/azyqzj3hez84rq1/apache-activemq-5.9.0-bin.tar.gz?dl=0"
export GET_ACTIVEMQ_FILE="apache-activemq-5.9.0-bin.tar.gz"
export ACTIVEMQ_TMP_PATH="/opt/apache-activemq-5.9.0"
export AMQ_USER="active_user"

#  Configure Identity Server parameters
export GET_IS_SITE="https://www.dropbox.com/s/l8bb5e0nuv4sfe4/wso2is-5.2.0.zip?dl=0"
export GET_IS_FILE="wso2is-5.2.0.zip"
export IS_TMP_PATH="/opt/wso2is-5.2.0"
export IS_USER="wso2_is"


#  Configure Complex Event Processor parameters
export GET_CEP_SITE="https://www.dropbox.com/s/fyj53zufqdvxtsw/wso2cep-4.2.0.zip?dl=0"
export GET_CEP_FILE="wso2cep-4.2.0.zip"
export CEP_TMP_PATH="/opt/wso2cep-4.2.0"
export CEP_USER="wso2_cep"


#  Configure ESB parameters
export GET_ESB_SITE="https://www.dropbox.com/s/guz2fheobgbyxye/wso2esb-5.0.0.zip?dl=0"
export GET_ESB_FILE="wso2esb-5.0.0.zip"
export ESB_TMP_PATH="/opt/wso2esb-5.0.0"
export ESB_USER="wso2_esb"


export DB1=""
export USER2=""
export PASS3=""

export GET_MYSQL_CONNECTOR="https://www.dropbox.com/s/a9qj46qwlbxsek6/mysql-connector-java-5.1.40-bin.jar?dl=0"
export GET_DATASOURCETEMPLATE_CONNECTOR="https://www.dropbox.com/s/uemt6tm31axs7lp/master-datasources.xml?dl=0"



#DB CEP
DBCEP=cep_db
DBUSERCEP=cep_user
DBPASSCEP=cep_password
#DB ESB
DBESB=esb_db
DBUSERESB=esb_user
DBPASSESB=esb_password
#DB IS
DBIS=is_db
DBUSERIS=is_user
DBPASSIS=is_password


#############################



# TEMP FIX - Re-evaluate and remove when possible
# This is an interim fix for hostname resolution in current VM (If it does not exist add it)
grep -q "${HOSTNAME}" /etc/hosts
if [ $? == 0 ];
then
  echo "${HOSTNAME}found in /etc/hosts"
else
  echo "${HOSTNAME} not found in /etc/hosts"
  # Append it to the hsots file if not there
  echo "127.0.0.1 ${HOSTNAME}" >> /etc/hosts
fi




# Get today's date into YYYYMMDD format
now=$(date +"%Y%m%d")
 
# Get passed in parameters $1, $2, $3, $4, and others...
MASTERIP=""
SUBNETADDRESS=""
NODETYPE=""
mysqlPassword=""  


#Loop through options passed
while getopts :m:s:t:p: optname; do
    mylog "Option $optname set with value ${OPTARG}"
  case $optname in
    m)
      MASTERIP=${OPTARG}
      ;;
  	s) #Data storage subnet space
      SUBNETADDRESS=${OPTARG}
      ;;
    t) #Type of node (MASTER/SLAVE)
      NODETYPE=${OPTARG}
      ;;
    p) #Replication Password
	  mysqlPassword=${OPTARG}
      ;;
    h)  #show help
      help
      exit 2
      ;;
    \?) #unrecognized option - show help
      echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
      help
      exit 2
      ;;
  esac
done



mylog "NOW=$now MASTERIP=$MASTERIP SUBNETADDRESS=$SUBNETADDRESS NODETYPE=$NODETYPE"

###### JAVA STEPS

setup_java() {
	mylog "Start installing java..."
    cd /opt
    wget  $GET_JAVA_SITE -O $GET_JAVA_FILE
	tar xvfz $GET_JAVA_FILE 
	ln -s $JAVA_TMP_PATH /opt/java
    #The jvm directory is used to organize all JDK/JVM versions in a single parent directory.	
	echo "export JAVA_HOME="/opt/java"" >> /etc/profile
    echo "export PATH="$PATH:$JAVA_HOME/bin"" >> /etc/profile
    mylog "Done installing Java, javahome is: $JAVA_TMP_PATH linked in /opt/java"	
}



setup_java_repo() {
    add-apt-repository -y ppa:webupd8team/java
    apt-get -q -y update  > /dev/null
    echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
    echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections
    apt-get -q -y install oracle-java8-installer  > /dev/null


#da fare linkare a /opt/java e java7
     echo "export JAVA_HOME="/opt/java"" >> ~/bashrc
    echo "export PATH="$PATH:$JAVA_HOME/bin"" >> ~/bashrc

}



######

######### Setup Disk OPT ###############
setup_diskopt() {
wget "https://raw.githubusercontent.com/Magopancione/AzureP/master/configureLVM.sh" -O configureLVM.sh
bash configureLVM.sh -optluns 0,1
}


######### Setup Disk OPT ###############
setup_diskDB() {
#vedi: https://azure.microsoft.com/it-it/documentation/articles/virtual-machines-linux-configure-lvm/
#Disable Apparmor	
/etc/init.d/apparmor teardown
update-rc.d -f apparmor remove
#Create Data
wget "https://raw.githubusercontent.com/Magopancione/AzureP/master/configureLVM.sh" -O configureLVM.sh
bash configureLVM.sh -dbluns 0,1
ls -s /mysql-DB /var/lib/mysql
}

################## END ##################



###### ACTIVEMQ STEPS


setup_activeMQ() {
	mylog "Start installing ActiveMQ..."
	source  /etc/profile
    cd /opt
    wget  $GET_ACTIVEMQ_SITE -O $GET_ACTIVEMQ_FILE
	tar xvfz $GET_ACTIVEMQ_FILE
    ln -s $ACTIVEMQ_TMP_PATH /opt/ActiveMQ

	mylog "Done installing ActiveMQ is installed in: $ACTIVEMQ_TMP_PATH  linked in /opt/ActiveMQ"	
	
	}
	
	
post_install_activeMQ() { 
	groupadd -g 1070 $AMQ_USER
	useradd -u 1070 -g 1070 $AMQ_USER
	chmod 755 /opt/ActiveMQ/bin/activemq
    ln -snf /opt/ActiveMQ/bin/activemq /etc/init.d/activemq_service
    update-rc.d activemq_service defaults
	chown -R $AMQ_USER:$AMQ_USER /opt
	echo -e "ACTIVEMQ_USER=$AMQ_USER\nJAVA_HOME="/opt/java"" >> /etc/default/activemq 
    service activemq_service start
}


test_activeMQ() {
sleep 20

GET_STATE=$( netstat -an|grep 61616| wc -l )

    if [ "$GET_STATE" == "1" ];
	then
	 mylog " ------Done ActiveMQ is Running on port 61616 -------"   # per la cluster conviene usare puppet
	fi
#INFO  ActiveMQ JMS Message Broker (ID:apple-s-Computer.local-51222-1140729837569-0:0) has started

}


limits_activeMQ() {

#limits

echo "* soft  nofile  999999" >> /etc/security/limits.conf
echo "* hard  nofile  999999" >> /etc/security/limits.conf

echo "* soft  nproc  999999"  >> /etc/security/limits.conf
echo "* hard  nproc  999999"  >> /etc/security/limits.conf

echo "root  soft  nofile 999999" >> /etc/security/limits.conf
echo "root  hard  nofile 999999" >> /etc/security/limits.conf

}


sysctl_activeMQ() {
echo "fs.file-max = 999999                         " > /etc/sysctl.conf
echo "                                             " >> /etc/sysctl.conf
echo "net.core.netdev_max_backlog = 10240          " >> /etc/sysctl.conf
echo "net.core.somaxconn = 10240                   " >> /etc/sysctl.conf
echo "                                             " >> /etc/sysctl.conf
echo "net.ipv4.conf.all.accept_redirects = 0       " >> /etc/sysctl.conf
echo "net.ipv4.conf.all.accept_source_route = 0    " >> /etc/sysctl.conf
echo "net.ipv4.conf.all.rp_filter = 1              " >> /etc/sysctl.conf
echo "net.ipv4.conf.all.secure_redirects = 0       " >> /etc/sysctl.conf
echo "                                             " >> /etc/sysctl.conf
echo "net.ipv4.conf.default.accept_redirects = 0   " >> /etc/sysctl.conf
echo "net.ipv4.conf.default.accept_source_route = 0" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.secure_redirects = 0   " >> /etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter = 1          " >> /etc/sysctl.conf
echo "                                             " >> /etc/sysctl.conf
echo "net.ipv4.ip_local_port_range = 1024 65535    " >> /etc/sysctl.conf
echo "                                             " >> /etc/sysctl.conf
echo "net.ipv4.icmp_echo_ignore_broadcasts = 1     " >> /etc/sysctl.conf
echo "                                             " >> /etc/sysctl.conf
echo "net.ipv4.tcp_fin_timeout = 15                " >> /etc/sysctl.conf
echo "net.ipv4.tcp_keepalive_probes = 5            " >> /etc/sysctl.conf
echo "net.ipv4.tcp_keepalive_time = 1800           " >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_orphans = 60000             " >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 10240         " >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_tw_buckets = 400000         " >> /etc/sysctl.conf
echo "net.ipv4.tcp_rmem = 4096 4096 16777216       " >> /etc/sysctl.conf
echo "net.ipv4.tcp_synack_retries = 3              " >> /etc/sysctl.conf
echo "net.ipv4.tcp_syncookies = 1                  " >> /etc/sysctl.conf
echo "net.ipv4.tcp_tw_recycle = 1                  " >> /etc/sysctl.conf
echo "net.ipv4.tcp_tw_reuse = 1                    " >> /etc/sysctl.conf
echo "net.ipv4.tcp_wmem = 4096 4096 16777216       " >> /etc/sysctl.conf



#rif https://gist.github.com/Jeraimee/3000974

}
	



#######################WS02 PRODUCT ####################


######   ESB STEPS

setup_ESB() {
	mylog "Start installing Enterpris Service Bus..."
	BASE=/opt/WSO2/esb
	apt-get install unzip -y
	mkdir -p /opt/WSO2/
	cd /opt/
    wget  $GET_ESB_SITE -O $GET_ESB_FILE 
	unzip $GET_ESB_FILE
	ln -s $ESB_TMP_PATH $BASE
	
	#procedura Mysql
    apt-get install -y mysql-client 
    BASE=$ESB_TMP_PATH 
	wget $GET_MYSQL_CONNECTOR -O $BASE/repository/components/lib/mysql-connector-java-5.1.40-bin.jar
    wget $GET_DATASOURCETEMPLATE_CONNECTOR  -O  $BASE/repository/conf/datasources/master-datasources.xml 
    sed -e "s/XX_IP_XX/10.0.2.10/g"  -i $BASE/repository/conf/datasources/master-datasources.xml 
	sed -e "s/XX_DB_XX/$DBESB/g" -i   $BASE/repository/conf/datasources/master-datasources.xml 
    sed -e "s/XX_USER_XX/$DBUSERESB/g" -i  $BASE/repository/conf/datasources/master-datasources.xml 
    sed -e "s/XX_PASSWORD_XX/$DBPASSESB/g"  -i  $BASE/repository/conf/datasources/master-datasources.xml 
    mysql -u$DBUSERESB -p$DBPASSESB -D$DBESB -h 10.0.2.10 < $BASE/dbscripts/mysql.sql
		
	#Crea Utente 
	groupadd -g 1010 $ESB_USER	
	useradd -u 1010 -g 1010 $ESB_USER
	chown -R  $ESB_USER:$ESB_USER $ESB_TMP_PATH 
    mylog "Done installing Enterpris Service Bus installed in: $ESB_TMP_PATH   linked in $BASE "	
	
}





post_install_ESB() {


# da verificare ssl
#/repository/conf/carbon.xml

echo "#! /bin/sh                                                                 " > /opt/WSO2/esb/esb_service
echo "export JAVA_HOME="/opt/java/"                                              " >> /opt/WSO2/esb/esb_service
echo "                                                                           " >> /opt/WSO2/esb/esb_service
echo "startcmd='/opt/WSO2/esb/bin/wso2server.sh start > /dev/null &'             " >> /opt/WSO2/esb/esb_service
echo "restartcmd='/opt/WSO2/esb/bin/wso2server.sh restart > /dev/null &'         " >> /opt/WSO2/esb/esb_service
echo "stopcmd='/opt/WSO2/esb/bin/wso2server.sh stop > /dev/null &'               " >> /opt/WSO2/esb/esb_service
echo "                                                                           " >> /opt/WSO2/esb/esb_service
echo "case \"\$1\" in                                                               " >> /opt/WSO2/esb/esb_service
echo "start)                                                                     " >> /opt/WSO2/esb/esb_service
echo "   echo \"Starting WSO2 Application Server ...\"                             " >> /opt/WSO2/esb/esb_service
echo "   su -c \"\${startcmd}\" $ESB_USER                                           " >> /opt/WSO2/esb/esb_service
echo ";;                                                                         " >> /opt/WSO2/esb/esb_service
echo "restart)                                                                   " >> /opt/WSO2/esb/esb_service
echo "   echo \"Re-starting WSO2 Application Server ...\"                          " >> /opt/WSO2/esb/esb_service
echo "   su -c \"\${restartcmd}\" $ESB_USER                                         " >> /opt/WSO2/esb/esb_service
echo ";;                                                                         " >> /opt/WSO2/esb/esb_service
echo "stop)                                                                      " >> /opt/WSO2/esb/esb_service
echo "   echo \"Stopping WSO2 Application Server ...\"                             " >> /opt/WSO2/esb/esb_service
echo "   su -c \"\${stopcmd}\" $ESB_USER                                            " >> /opt/WSO2/esb/esb_service
echo ";;                                                                         " >> /opt/WSO2/esb/esb_service
echo "*)                                                                         " >> /opt/WSO2/esb/esb_service
echo "   echo \"Usage: \$0 {start|stop|restart}\"                                   " >> /opt/WSO2/esb/esb_service
echo "exit 1                                                                     " >> /opt/WSO2/esb/esb_service
echo "esac                                                                       " >> /opt/WSO2/esb/esb_service



 
chmod a+x /opt/WSO2/esb/esb_service
ln -snf /opt/WSO2/esb/esb_service /etc/init.d/esb_service
update-rc.d esb_service defaults
service esb_service start
}



######   CEP STEPS

setup_CEP() {
	mylog " Start installing Complex Event Processor..."
	apt-get install unzip -y
	BASE=/opt/WSO2/cep
	mkdir -p /opt/WSO2/
	cd /opt/
    wget  $GET_CEP_SITE -O $GET_CEP_FILE 
	unzip $GET_CEP_FILE    
	ln -s $CEP_TMP_PATH $BASE

    	#procedura Mysql
    apt-get install -y mysql-client 
	wget $GET_MYSQL_CONNECTOR -O $BASE/repository/components/lib/mysql-connector-java-5.1.40-bin.jar
    wget $GET_DATASOURCETEMPLATE_CONNECTOR  -O  $BASE/repository/conf/datasources/master-datasources.xml 
    sed -e "s/XX_IP_XX/10.0.2.10/g"  -i $BASE/repository/conf/datasources/master-datasources.xml 
	sed -e "s/XX_DB_XX/$DBCEP/g" -i   $BASE/repository/conf/datasources/master-datasources.xml 
    sed -e "s/XX_USER_XX/$DBUSERCEP/g" -i  $BASE/repository/conf/datasources/master-datasources.xml 
    sed -e "s/XX_PASSWORD_XX/$DBPASSCEP/g"  -i  $BASE/repository/conf/datasources/master-datasources.xml 
    mysql -u$DBUSERCEP -p$DBPASSCEP -D$DBCEP -h 10.0.2.10 < $BASE/dbscripts/mysql.sql

    #Crea Utente 
    groupadd -g 1020 $CEP_USER	
    useradd -u 1020 -g 1020 $CEP_USER
	chown -R  $CEP_USER:$CEP_USER $CEP_TMP_PATH


 
    mylog " Done installing WSO2 Complex Event Processor installed in: $CEP_TMP_PATH   linked in /opt/WSO2/cep"	
	
}



post_install_CEP() {


# da verificare ssl
#/repository/conf/carbon.xml

#Crea servizio
echo " #! /bin/sh                                                       " >  /opt/WSO2/cep/cep_service
echo "export JAVA_HOME=\"/opt/java/\"                                     " >> /opt/WSO2/cep/cep_service
echo "                                                                  " >> /opt/WSO2/cep/cep_service
echo "startcmd='/opt/WSO2/cep/bin/wso2server.sh start > /dev/null &'    " >> /opt/WSO2/cep/cep_service
echo "restartcmd='/opt/WSO2/cep/bin/wso2server.sh restart > /dev/null &'" >> /opt/WSO2/cep/cep_service
echo "stopcmd='/opt/WSO2/cep/bin/wso2server.sh stop > /dev/null &'      " >> /opt/WSO2/cep/cep_service
echo "                                                                  " >> /opt/WSO2/cep/cep_service
echo "case \"\$1\" in                                                      " >> /opt/WSO2/cep/cep_service
echo "start)                                                            " >> /opt/WSO2/cep/cep_service
echo "   echo \"Starting WSO2 Complex Event Processor ...\"               " >> /opt/WSO2/cep/cep_service
echo "   su -c \"\${startcmd}\" $CEP_USER                                  " >> /opt/WSO2/cep/cep_service
echo ";;                                                                " >> /opt/WSO2/cep/cep_service
echo "restart)                                                          " >> /opt/WSO2/cep/cep_service
echo "   echo \"Re-starting WSO2 Complex Event Processor ...\"            " >> /opt/WSO2/cep/cep_service
echo "   su -c """\${restartcmd}""" $CEP_USER                                " >> /opt/WSO2/cep/cep_service
echo ";;                                                                " >> /opt/WSO2/cep/cep_service
echo "stop)                                                             " >> /opt/WSO2/cep/cep_service
echo "   echo \"Stopping WSO2 Complex Event Processor ...\"               " >> /opt/WSO2/cep/cep_service
echo "   su -c \"\${stopcmd}\" $CEP_USER                                   " >> /opt/WSO2/cep/cep_service
echo ";;                                                                " >> /opt/WSO2/cep/cep_service
echo "*)                                                                " >> /opt/WSO2/cep/cep_service
echo "   echo \"Usage: \$0 {start|stop|restart}\"                          " >> /opt/WSO2/cep/cep_service
echo "exit 1                                                            " >> /opt/WSO2/cep/cep_service
echo "esac                                                              " >> /opt/WSO2/cep/cep_service

 
chmod a+x /opt/WSO2/cep/cep_service
ln -snf /opt/WSO2/cep/cep_service /etc/init.d/cep_service
update-rc.d cep_service defaults


service cep_service start
}

### POST SETUP CEP


#apt-get -y install  mysql-client
#mysql -u root -p 
#create database regdb character set latin1;
#GRANT ALL ON regdb.* TO regadmin@localhost IDENTIFIED BY "regadmin";
#FLUSH PRIVILEGES;
#quit;
#mysql -u regadmin -p -Dregdb < '<PRODUCT_HOME>/dbscripts/mysql.sql';
#For Linux: <PRODUCT_HOME>/bin/wso2server.sh -Dsetup
#####




###### IS STEPS

setup_IS() {
	mylog "Start installing java..."

	apt-get install unzip -y
	BASE=/opt/WSO2/IdentityServer
	mkdir -p /opt/WSO2/
	cd /opt/
    wget  $GET_IS_SITE -O $GET_IS_FILE 
	unzip $GET_IS_FILE
	ln -s $IS_TMP_PATH $BASE

    #procedura Mysql
    apt-get install -y mysql-client 
	BASE=$IS_TMP_PATH
	wget $GET_MYSQL_CONNECTOR -O $BASE/repository/components/lib/mysql-connector-java-5.1.40-bin.jar
    wget $GET_DATASOURCETEMPLATE_CONNECTOR  -O  $BASE/repository/conf/datasources/master-datasources.xml 
    sed -e "s/XX_IP_XX/10.0.2.10/g"  -i $BASE/repository/conf/datasources/master-datasources.xml 
	sed -e "s/XX_DB_XX/$DBIS/g" -i   $BASE/repository/conf/datasources/master-datasources.xml 
    sed -e "s/XX_USER_XX/$DBUSERIS/g" -i  $BASE/repository/conf/datasources/master-datasources.xml 
    sed -e "s/XX_PASSWORD_XX/$DBPASSIS/g"  -i  $BASE/repository/conf/datasources/master-datasources.xml 
    mysql -u$DBUSERIS -p$DBPASSIS -D$DBIS -h 10.0.2.10 < $BASE/dbscripts/mysql.sql
		
	#Crea Utente 
	groupadd -g 1030 $IS_USER	
	useradd -u 1030 -g 1030 $IS_USER
	chown -R  $IS_USER:$IS_USER  $IS_TMP_PATH 
    
 
    mylog "Done installing Identiy Server installed in: $IS_TMP_PATH  linked in $BASE"
	
}


post_install_IS() {


# da verificare ssl
#/repository/conf/carbon.xml


#Crea servizio
echo " #! /bin/sh                                                                   " > /opt/WSO2/IdentityServer/is_service
echo " export JAVA_HOME=\"/opt/java\"                                               " >> /opt/WSO2/IdentityServer/is_service
echo "                                                                              " >> /opt/WSO2/IdentityServer/is_service
echo " startcmd='/opt/WSO2/IdentityServer/bin/wso2server.sh start > /dev/null &'    " >> /opt/WSO2/IdentityServer/is_service
echo " restartcmd='/opt/WSO2/IdentityServer/bin/wso2server.sh restart > /dev/null &'" >> /opt/WSO2/IdentityServer/is_service
echo " stopcmd='/opt/WSO2/IdentityServer/bin/wso2server.sh stop > /dev/null &'      " >> /opt/WSO2/IdentityServer/is_service
echo "                                                                              " >> /opt/WSO2/IdentityServer/is_service
echo " case \"\$1\" in                                                              " >> /opt/WSO2/IdentityServer/is_service
echo " start)                                                                       " >> /opt/WSO2/IdentityServer/is_service
echo "    echo \"Starting WSO2 Application Server ...\"                             " >> /opt/WSO2/IdentityServer/is_service
echo "    su -c \"\${startcmd}\" $IS_USER                                           " >> /opt/WSO2/IdentityServer/is_service
echo " ;;                                                                           " >> /opt/WSO2/IdentityServer/is_service
echo " restart)                                                                     " >> /opt/WSO2/IdentityServer/is_service
echo "    echo \"Re-starting WSO2 Application Server ...\"                          " >> /opt/WSO2/IdentityServer/is_service
echo "    su -c \"\${restartcmd}\" $IS_USER                                         " >> /opt/WSO2/IdentityServer/is_service
echo " ;;                                                                           " >> /opt/WSO2/IdentityServer/is_service
echo " stop)                                                                        " >> /opt/WSO2/IdentityServer/is_service
echo "    echo \"Stopping WSO2 Application Server ...\"                             " >> /opt/WSO2/IdentityServer/is_service
echo "    su -c \"\${stopcmd}\" $IS_USER                                            " >> /opt/WSO2/IdentityServer/is_service
echo " ;;                                                                           " >> /opt/WSO2/IdentityServer/is_service
echo " *)                                                                           " >> /opt/WSO2/IdentityServer/is_service
echo "    echo \"Usage: \$0 {start|stop|restart}\"                                  " >> /opt/WSO2/IdentityServer/is_service
echo " exit 1                                                                       " >> /opt/WSO2/IdentityServer/is_service
echo " esac                                                                         " >> /opt/WSO2/IdentityServer/is_service
 
chmod a+x /opt/WSO2/IdentityServer/is_service
ln -snf /opt/WSO2/IdentityServer/is_service /etc/init.d/is_service
update-rc.d is_service defaults


service is_service start
}


######### GENERAL FO WSO2

sysctl_install_IS_CEP_ESB() {
echo "net.ipv4.tcp_fin_timeout = 30  " >> /etc/sysctl.conf
echo "fs.file-max = 2097152                    ">> /etc/sysctl.conf
echo "net.ipv4.tcp_tw_recycle = 1              ">> /etc/sysctl.conf
echo "net.ipv4.tcp_tw_reuse = 1                ">> /etc/sysctl.conf
echo "net.core.rmem_default = 524288           ">> /etc/sysctl.conf
echo "net.core.wmem_default = 524288           ">> /etc/sysctl.conf
echo "net.core.rmem_max = 67108864             ">> /etc/sysctl.conf
echo "net.core.wmem_max = 67108864             ">> /etc/sysctl.conf
echo "net.ipv4.tcp_rmem = 4096 87380 16777216  ">> /etc/sysctl.conf
echo "net.ipv4.tcp_wmem = 4096 65536 16777216  ">> /etc/sysctl.conf
echo "net.ipv4.ip_local_port_range = 1024 65535">> /etc/sysctl.conf
}


limits_IS_CEP_ESB() {
#limits

echo "* soft nofile 4096" >> /etc/security/limits.conf
echo "* hard nofile 65535" >> /etc/security/limits.conf

echo "* soft nproc 20000" >> /etc/security/limits.conf
echo "* hard nproc 20000" >> /etc/security/limits.conf

}



######
crea_utenti_mysql(){
MYSQL=$(which mysql)
Q1="CREATE DATABASE IF NOT EXISTS $DB1;"
Q2="GRANT USAGE ON *.* TO $USER2@'%' IDENTIFIED BY '$PASS3';"
Q3="GRANT ALL PRIVILEGES ON $DB1.* TO $USER2@'%';"
Q4="FLUSH PRIVILEGES;"
SQL="${Q1}${Q2}${Q3}${Q4}"
$MYSQL -uroot -p$mysqlPassword -e "$SQL"
}

########### MYSQL Setup
setup_MYSQL() {
#no password prompt while installing mysql server
#export DEBIAN_FRONTEND=noninteractive

#another way of installing mysql server in a Non-Interactive mode
echo "mysql-server-5.6 mysql-server/root_password password $mysqlPassword" | sudo debconf-set-selections 
echo "mysql-server-5.6 mysql-server/root_password_again password $mysqlPassword" | sudo debconf-set-selections 

#install mysql-server 5.6
apt-get -y install mysql-server-5.6

echo "  [mysqld]  " > /etc/mysql/conf.d/wso2.cnf 
echo "  bind-address  = 0.0.0.0 " >> /etc/mysql/conf.d/wso2.cnf 

#create database regdb character set latin1;
#GRANT ALL ON regdb.* TO regadmin@localhost IDENTIFIED BY "regadmin";
#FLUSH PRIVILEGES;
#quit;




sleep 10


#DB CEP

#DB ESB
#$DB1=esb_db
#$USER2=esb_user
#$PASS3=esb_password
#crea_uenti_mysql()
#DB IS
#$DB1=is_db
#$USER2=is_user
#$PASS3=is_password
#crea_uenti_mysql()


#create database regdb character set latin1;
#GRANT ALL ON regdb.* TO regadmin@localhost IDENTIFIED BY "regadmin";
#FLUSH PRIVILEGES;
#quit;

#set the password
#sudo mysqladmin -u root password "$mysqlPassword"   #without -p means here the initial password is empty

#alternative update mysql root password method
#sudo mysql -u root -e "set password for 'root'@'localhost' = PASSWORD('$mysqlPassword')"
#without -p here means the initial password is empty
service mysql restart

}

###########



#setup_datadisks() {
#
#	MOUNTPOINT="/datadisks/disk1"
#
#	# Move database files to the striped disk
#	if [ -L /var/lib/kafkadir ];
#	then
#		mylog "Symbolic link from /var/lib/kafkadir already exists"
#		echo "Symbolic link from /var/lib/kafkadir already exists"
#	else
#		mylog "Moving  data to the $MOUNTPOINT/kafkadir"
#		echo "Moving PostgreSQL data to the $MOUNTPOINT/kafkadir"
#		service postgresql stop
#		mkdir $MOUNTPOINT/kafkadir
#		mv -f /var/lib/kafkadir $MOUNTPOINT/kafkadir
#
#		# Create symbolic link so that configuration files continue to use the default folders
#		mylog "Create symbolic link from /var/lib/kafkadir to $MOUNTPOINT/kafkadir"
#		ln -s $MOUNTPOINT/kafkadir /var/lib/kafkadir
#	fi
#}



setup_product() {

	if [ "$NODETYPE" == "ACTIVEMQ" ];
	then
	 mylog " ------Start Install ActiveMQ------"
	 #Impostazione base di sistema
	 setup_diskopt
     limits_activeMQ
	 setup_java
     sysctl_activeMQ
     
     #setup of ActiveMQ
     setup_activeMQ
	 post_install_activeMQ     
	 #test of ActiveMQ
     test_activeMQ
	mylog " ------Done configuring ACTIVEMQ-------"
	fi
	
	
	
	if [ "$NODETYPE" == "IS" ];
	then
	 setup_diskopt
	 setup_java
	 sysctl_install_IS_CEP_ESB
	 limits_IS_CEP_ESB
	 setup_IS
	 post_install_IS
	mylog " ------Done configuring IS-------"
	fi
	

	
		
    if [ "$NODETYPE" == "CEP" ];
	then
	 setup_diskopt
	 setup_java
	 sysctl_install_IS_CEP_ESB
	 limits_IS_CEP_ESB
	 setup_CEP
	 post_install_CEP
	 mylog " ------Done configuring CEP -------"   # per la cluster conviene usare puppet
	fi
	
	
			
    if [ "$NODETYPE" == "ESB" ];
	then
	 setup_diskopt
	 setup_java
	 sysctl_install_IS_CEP_ESB
	 limits_IS_CEP_ESB
	 setup_ESB
	 post_install_ESB
	mylog " ------Done configuring ESB -------"
	fi
	

    if [ "$NODETYPE" == "MYSQL" ];
	then
	 setup_diskDB
	 setup_MYSQL         
	 #DB CEP
         DB1=$DBCEP
         USER2=$DBUSERCEP
         PASS3=$DBPASSCEP
         crea_utenti_mysql
    #DB ESB
         DB1=$DBESB
         USER2=$DBUSERESB
         PASS3=$DBPASSESB
         crea_utenti_mysql
    #DB IS
         DB1=$DBIS
         USER2=$DBUSERIS
         PASS3=$DBPASSIS
         crea_utenti_mysql
	fi
	mylog " ------Done configuring CEP ------- "

}





# MAIN ROUTINE
#aggiorna i repo
apt-get -y update

#Setup della JVM

setup_product