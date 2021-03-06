#!/bin/bash

set -e

mkdir -p environments/tci-server
cd environments/tci-server

if [ ! -f tci.config ]; then
    cp ../../src/resources/config/tci-server/tci.config.template tci.config
fi
source tci.config

sed "s/TCI_SERVER_TITLE_TEXT/${TCI_SERVER_TITLE_TEXT}/ ; s/TCI_SERVER_TITLE_COLOR/${TCI_SERVER_TITLE_COLOR}/ ; s/TCI_BANNER_COLOR/${TCI_BANNER_COLOR}/" ../../src/resources/config/tci-server/tci.css.template > tci.css

if [ ! -f docker-compose.yml ]; then
    cp ../../src/resources/config/tci-server/docker-compose.yml.template docker-compose.yml
fi
if [ ! -f config.yml ]; then
    cp ../../src/resources/config/tci-server/config.yml.template config.yml
fi
if [ ! -f org.codefirst.SimpleThemeDecorator.xml ]; then
    cp ../../src/resources/config/org.codefirst.SimpleThemeDecorator.xml.template org.codefirst.SimpleThemeDecorator.xml
fi

# set action defaulted to 'restart'
action='restart'
if [[ $# > 0 ]]; then
   action=$1
fi

if [ ! -n "$TCI_HOST_IP" ]; then
    export TCI_HOST_IP="$(/sbin/ifconfig | grep 'inet ' | grep -Fv 127.0.0.1 | awk '{print $2}' | head -n 1 | sed -e 's/addr://')"
fi
export GIT_PRIVATE_KEY=`cat $GITHUB_PRIVATE_KEY_FILE_PATH`


if [[ "$action" == "info" ]]; then
    echo [Server host IP address] $TCI_HOST_IP
    echo [Private SSH key file path] $GITHUB_PRIVATE_KEY_FILE_PATH
    exit 0
fi

if [[ "$action" == "stop" || "$action" == "restart" ]]; then
   docker-compose down --remove-orphans
   sleep 2
fi

if [[ "$action" == "start"  || "$action" == "restart" ]]; then

    docker pull tikalci/tci-master
    docker tag tikalci/tci-master tci-master

    mkdir -p .data/jenkins_home/userContent
    cp -f ../../src/resources/images/tci-small-logo.png .data/jenkins_home/userContent | true
    cp -f tci.css .data/jenkins_home/userContent/tci.css | true
    cp -f org.codefirst.SimpleThemeDecorator.xml .data/jenkins_home | true
    docker-compose up -d
    sleep 2
    counter=0
    docker-compose logs -f | while read LOGLINE
    do
        if [[ $counter == 0 ]]; then
            echo -n "*"
        else
            echo -n .
        fi
        [[ "${LOGLINE}" == *"Entering quiet mode. Done..."* ]] && pkill -P $$ docker-compose
        counter=$(( $counter + 1 ))
        if [[ $counter == 5 ]]; then
            counter=0
        fi
    done

fi
