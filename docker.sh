#!/usr/bin/env bash

set -euxo pipefail

COMMAND=$1

if [ "$COMMAND" = "login" ]; then
   if [ -z "${CI:-}" ]; then
      PROFILE="--profile engineering"
    else
      PROFILE=""
    fi
    $(aws $PROFILE ecr get-login --region us-east-1)
    exit 0
fi

VERSION=$2
IMAGE=450769122572.dkr.ecr.us-east-1.amazonaws.com/splunk-for-test:${VERSION}
IMAGE_LOCAL=splunk-for-test:${VERSION}

PORTS="-p 8000:8000 -p 8089:8089 -p 8191:8191 -p 12300:12300 -p 1514:1514 -p 8088:8088 \
       -p 8200:8000 -p 8289:8289 -p 8391:8391 -p 12500:12500 -p 1714:1714 -p 8288:8288"

case "$COMMAND" in
  pull)
    docker pull ${IMAGE}
    ;;
  run)
    docker run -d ${PORTS} ${IMAGE}
    ;;
  stop)
    docker stop $(docker ps -q --filter ancestor=${IMAGE})
    ;;
  debug_run)
    docker run ${PORTS} ${IMAGE_LOCAL} --debug
    ;;
  build)
    docker build --no-cache=true -t ${IMAGE_LOCAL} test/Dockerfiles/enterprise/${VERSION}
    ;;
  push)
    docker tag ${IMAGE_LOCAL} ${IMAGE}
    docker push ${IMAGE}
    ;;
  load_or_pull)
    # only for CI
    CACHE_DIR=~/docker
    CACHE_IMAGE=${CACHE_DIR}/image-${VERSION}.tar
    if [ -z "${CI:-}" ]; then
      echo "load and pull is available only on CI"
      exit 1
    fi
    if [[ -e ${CACHE_IMAGE} ]]; then
      echo "Loading golang docker image from cache"
      docker load -i ${CACHE_IMAGE}
    else
      echo "Pulling golang docker image from Docker Hub"
      docker pull ${IMAGE}
      mkdir -p ${CACHE_DIR}; docker save -o ${CACHE_IAMGE} ${IMAGE}
    fi
    ;;
  *)
    echo "Unkowon command"
    ;;
esac
