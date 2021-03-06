#!/bin/bash

UP_DOWN=$1
CH_NAME=$2
CHANNELS=$3
CHAINCODES=$4
ENDORSERS=$5

: ${CH_NAME:="mychannel"}
: ${CHANNELS:="2"}
: ${CHAINCODES:="2"}
: ${ENDORSERS:="4"}
COMPOSE_FILE=docker-compose-no-tls.yaml

function printHelp () {
	echo "Usage: ./network_setup <up|down|restart> [channel-name [total-channels [chaincodes [endorsers count]]]]"
}

function printArgs () {
        echo "Args:"
        echo "CH_NAME=$CH_NAME"
        echo "CHANNELS=$CHANNELS"
        echo "CHAINCODES=$CHAINCODES"
        echo "ENDORSERS=$ENDORSERS"
}

function validateArgs () {
	if [ -z "${UP_DOWN}" ]; then
		echo "Option up / down / restart not mentioned"
		printHelp
		exit 1
	fi
}

function clearContainers () {
        CONTAINER_IDS=$(docker ps -aq)
        if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" = " " ]; then
                echo "---- No containers available for deletion ----"
        else
                docker rm -f $CONTAINER_IDS
        fi
}

function removeUnwantedImages() {
        DOCKER_IMAGE_IDS=$(docker images | grep "dev\|none\|test-vp\|peer[0-9]-" | awk '{print $3}')
        if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" = " " ]; then
                echo "---- No images available for deletion ----"
        else
                docker rmi -f $DOCKER_IMAGE_IDS
        fi
}

function networkUp () {
	CURRENT_DIR=$PWD
        source generateCfgTrx.sh $CH_NAME $CHANNELS
	cd $CURRENT_DIR

	CHANNEL_NAME=$CH_NAME CHANNELS_NUM=$CHANNELS CHAINCODES_NUM=$CHAINCODES ENDORSERS_NUM=$ENDORSERS docker-compose -f $COMPOSE_FILE up -d 2>&1
	if [ $? -ne 0 ]; then
		echo "ERROR !!!! Unable to pull the images "
		exit 1
	fi
	docker logs -f cli
}

function networkDown () {
        docker-compose -f $COMPOSE_FILE down
        #Cleanup the chaincode containers
	clearContainers
	#Cleanup images
	removeUnwantedImages
        #remove orderer service genesis block and any channel creation config transactions
        rm -rf $PWD/crypto/orderer/orderer.block
        rm -rf $PWD/crypto/orderer/channel*.tx
}

validateArgs
printArgs

#Create the network using docker compose
if [ "${UP_DOWN}" == "up" ]; then
	networkUp
elif [ "${UP_DOWN}" == "down" ]; then ## Clear the network
	networkDown
elif [ "${UP_DOWN}" == "restart" ]; then ## Restart the network
	networkDown
	networkUp
else
	printHelp
	exit 1
fi
