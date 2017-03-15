#!/bin/bash

set -e

COMMAND=$1
VERSION=$2
REPO=450769122572.dkr.ecr.us-east-1.amazonaws.com/splunk-for-test:${VERSION}
#REPO=splunk-for-test:${VERSION}

PORTS="-p 8000:8000 -p 8089:8089 -p 8191:8191 -p 12300:12300 -p 1514:1514 -p 8088:8088 \
       -p 8200:8000 -p 8289:8289 -p 8391:8391 -p 12500:12500 -p 1714:1714 -p 8288:8288"

case "$COMMAND" in
  login)
    if [ -z "${CI:-}" ]; then
      PROFILE="--profile engineering"
    else
      PROFILE=""
    fi
    $(aws $PROFILE ecr get-login --region us-east-1)
    ;;
  pull)
    docker pull ${REPO}
    ;;
  run)
    docker run -d ${PORTS} ${REPO}
    ;;
  debug_run)
    docker run ${PORTS} ${REPO}
    ;;
  *)
    echo "Unkowon command"
    ;;
esac
