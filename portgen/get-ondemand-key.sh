#!/bin/bash
cd $( dirname $0 )

##########################################################
## License: GNU GPL v3.                                 ##
## See LICENSE file or GNU Foundation site for details. ##
## Copyright (c) Raegdan, 2014-2015                     ##
## All rights reserved.                                 ##
##########################################################

###   C O N F I G   ###
#######################

LINK="https://example.tld/ondemand.key"

## Leave blank if no proxy
HTTP_PROXY=""
HTTPS_PROXY=$HTTP_PROXY

## seconds
TIMEOUT=30

## adjust for multi-portgen system
CACHE_FILE="portgen.ondemand-key.cache"

###   C O D E   ###
###################

NEWKEY=$( http_proxy=$HTTP_PROXY https_proxy=$HTTPS_PROXY wget  -t 1 -T $TIMEOUT -O - $LINK 2>/dev/null )
if [[ $? == 0 ]]; then
        ## Key download OK -- use it and update cache
        echo $NEWKEY | tee $CACHE_FILE
else
        ## Key download failed -- use cache
        cat $CACHE_FILE
fi

