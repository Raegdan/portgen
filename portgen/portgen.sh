#!/bin/bash
cd $( dirname $0 )

##########################################################
## License: GNU GPL v3.                                 ##
## See LICENSE file or GNU Foundation site for details. ##
## Copyright (c) Raegdan, 2014-2015                     ##
## All rights reserved.                                 ##
##########################################################

#########################################################################
## Please chown 0:0 && chmod 700 this file as it contains secret keys! ##
#########################################################################

###   C O N F I G   ###
#######################

## Secret key, must be the same on both sides.
## Protect it harder than your porn collection!
## Best way to form it is: dd if=/dev/random bs=1 count=256 | sha256sum
## ( unless you have "true RNG" based on radio noise / semiconductor noise /
## radioactive decay / quantum stuff / human-seeded RNG / etc. )
SHARED_KEY="DaMuthaFuckinSecretSharedKey"

## Not so secret key. Provides automatic port change on time basis. Even on control loss.
## NB: set up NTP on both sides, or you will face connectivity gaps!
## NB #2: always use UTC (date -u)!
TIMEBASED_KEY=$( date -u "+%Y&m%d" )$(( $( date -u "+%-H" ) / 6 ))

## Not so secret key. Store it on a reliable 3rd party server and get
## the ability to initiate port change anytime anywhere.
## See the respective script for details.
ONDEMAND_KEY=$( ./get-ondemand-key.sh )

## Server: where does it listen. Client: where do you connect to w/o portgen.
STATIC_PORT=6666
PROTOCOL="udp"
SERVER_IP="12.34.56.78"

## Nuff said
MODE="server"
#MODE="client"

## For server mode: WAN iface
IFACE=eth0

## Just some perma storage, adjust for multi-portgen system
CACHE_FILE="portgen.cache"
OLD_RULE_FILE="portgen.old-rule"

## Consider using non-round numbers here to get plausible randomness,
## otherwise ports will often end to zeros and fives (my empirical IMHO)
PORT_START=12121
PORT_COUNT=34343

## Uncomment to sync datetime every time portgen is executed.
## If you execute portgen often for on-demand key checking (interval < 1-2 hours),
## better use a dedicated cron job for NTP.
## Try playing with -u key if ntpdate glitches.
#ntpdate -u pool.ntp.org

###   C O D E   ###
###################

log () {
	echo $( date -u "+[%Y-%m-%d %H:%M:%S UTC] " )$@
}

delRule() {
	if [[ $( cat $OLD_RULE_FILE ) != "" ]]; then
		case $1 in
			server)
				CHAIN=PREROUTING
			;;

			client)
				CHAIN=OUTPUT
			;;
		esac

		iptables -t nat -D $CHAIN $( cat $OLD_RULE_FILE )
		log old rule deleted
	fi
}

addRule() {
	case $1 in
		server)
			RULE="-i $IFACE -d $SERVER_IP -p $PROTOCOL --dport $PORT -j DNAT --to-destination $SERVER_IP:$STATIC_PORT"
			iptables -t nat -I PREROUTING 1 $RULE
		;;

		client)
			RULE="-d $SERVER_IP -p $PROTOCOL --dport $STATIC_PORT -j DNAT --to-destination $SERVER_IP:$PORT"
			iptables -t nat -I OUTPUT 1 $RULE
		;;
	esac

	log iptables rule added
	echo $RULE > ./$OLD_RULE_FILE
}

HASH=$( echo ${TIMEBASED_KEY}${SHARED_KEY}${ONDEMAND_KEY} | md5sum | cut -c 1-14 )
CACHE=$( echo ${HASH}:$PORT_START:$PORT_COUNT | md5sum | cut -d\  -f1 )

if [[ $( cat ./${CACHE_FILE} 2>/dev/null ) == $CACHE ]]; then
	log Key not changed -- exiting!
	exit 0
fi

echo $CACHE > ./$CACHE_FILE

PORT=$(( $( printf "%d\n" 0x${HASH} ) % $PORT_COUNT + $PORT_START ))

log Key changed!
log New port: $PORT

case $MODE in
	server|client)
		delRule $MODE
		addRule $MODE
	;;

	*)
		log '$MODE must be set to "server" or "client". Halting portgen.'
		exit 1
	;;
esac

service openvpn restart
log OpenVPN restarted.

log portgen finished.

exit 0
