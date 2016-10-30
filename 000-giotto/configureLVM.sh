#!/bin/bash
function log()
{
	message=$1
	echo "$message"
	echo "$message" >> /var/log/lv-create
	curl -X POST -H "content-type:text/plain" --data-binary "${HOSTNAME} - $message" https://logs-01.loggly.com/inputs/72e878ca-1b43-4fb5-87ea-f78b6f378840/tag/ES_SCRIPT,${HOSTNAME}
   
}

function addtofstab()
{
	log "addtofstab"
	partPath=$1
	local blkid=$(/sbin/blkid $partPath)
	if [[ $blkid =~  UUID=\"(.{36})\" ]]
	then
		log "Adding fstab entry"
		local uuid=${BASH_REMATCH[1]};
		local mountCmd=""
		log "adding fstab entry"
		mountCmd="/dev/disk/by-uuid/$uuid $mountPath xfs  defaults,nofail  0  2"
		echo "$mountCmd" >> /etc/fstab
		$(mount $mountPath)
	else
		log "no UUID found"
		exit -1;
	fi
	log "addtofstab done"
}

function getdevicepath()
{
	log "getdevicepath"
	getdevicepathresult=""
	local lun=$1
	local scsiOutput=$(lsscsi)
	if [[ $scsiOutput =~ \[5:0:0:$lun\][^\[]*(/dev/sd[a-zA-Z]{1,2}) ]];
	then 
		getdevicepathresult=${BASH_REMATCH[1]};
	else
		log "lsscsi output not as expected for $lun"
		exit -1;
	fi
	log "getdevicepath done"
}

function createlvm()
{
	log "createlvm"
	
	lunsA=(${1//,/ })	
	vgName=$2
	lvName=$3
	mountPath=$4

	arraynum=${#lunsA[@]}
	echo "count $arraynum"
	if [[ $arraynum -gt 1 ]]
	then
		log "createlvm - creating lvm"
		
		numRaidDevices=0
		raidDevices=""
		num=${#lunsA[@]}
		log "num luns $num"
		for ((i=0; i<num; i++))
		do
			log "trying to find device path"
			lun=${lunsA[$i]}
			getdevicepath $lun
			devicePath=$getdevicepathresult;
			if [ -n "$devicePath" ];
			then
				log " Device Path is $devicePath"
				numRaidDevices=$((numRaidDevices + 1))
				raidDevices="$raidDevices $devicePath "				
			else
				log "no device path for LUN $lun"
				exit -1;
			fi
		done
		log "num: $numRaidDevices paths: '$raidDevices'"
		log $(pvcreate $raidDevices)
		log $(vgcreate $vgName $raidDevices)
		log $(lvcreate --extents 100%FREE --stripes $numRaidDevices --name $lvName $vgName)
		log $(mkfs -t xfs /dev/$vgName/$lvName)

		$(mkdir $mountPath)
		addtofstab /dev/$vgName/$lvName		
	else
		log "createlvm - creating single disk"
		
		lun=${lunsA[0]}
		getdevicepath $lun;
		devicePath=$getdevicepathresult;
		if [ -n "$devicePath" ];
		then
			log " Device Path is $devicePath"
			# http://superuser.com/questions/332252/creating-and-formating-a-partition-using-a-bash-script
			$(echo -e "n\np\n1\n\n\nw" | fdisk $devicePath)
			partPath="$devicePath""1"
			$(mkfs -t xfs $partPath)
			$(mkdir $mountPath)	

			addtofstab $partPath
		else
			log "no device path for LUN $lun"
			exit -1;
		fi
	fi

	log "createlvm done"

}

apt-get install -y xfsprogs lvm2 lsscsi
#bash configureLVM.sh -dbluns 0,1
#bash configureLVM.sh -optluns 0,1
#montato su opportuno mount point
db_new="\/var\/lib\/mysql"
dbluns=""
dbname="mysql-DB"
optluns=""
optname="opt"
datadiskluns=""
datadiskname="datadisks"
while true; do
	case "$1" in
    "-dbluns")  dbluns=$2;shift 2;
        ;;
    "-optluns")  optluns=$2;shift 2;
	    ;;
	"-datadiskluns")  datadiskluns=$2;shift 2;
        ;;
	"-dbname")  dbname=$2;shift 2;
        ;;
	"-optname")  optname=$2;shift 2;
        ;;
	"-datadiskname")  datadiskname=$2;shift 2;
        ;;
    esac
	if [[ -z "$1" ]]; then break; fi
done

if [[ -n "$datadiskluns" ]];
then
	createlvm $datadiskluns "vg-$datadiskname" "lv-$datadiskname" "/$datadiskname";
fi

if [[ -n "$dbluns" ]];
then
	createlvm $dbluns "vg-$dbname" "lv-$dbname" "/$dbname"
        umount /$dbname
		mkdir -p /var/lib/mysql
        sed -e "s/$dbname/$db_new/g"  -i /etc/fstab
    mount -a

fi

if [[ -n "$optluns" ]];
then
	createlvm $optluns "vg-$optname" "lv-$optname" "/$optname";
fi
