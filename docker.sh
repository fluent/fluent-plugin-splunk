#!/usr/bin/env bash

set -euxo pipefail

COMMAND=$1

if [ "$COMMAND" = "login" ]; then
   if [ -z "${CI:-}" ]; then
      PROFILE="--profile engineering"
    else
      PROFILE=""
    fi
    $(aws $PROFILE ecr get-login --region us-east-1 --no-include-email)
    exit 0
fi

VERSION=$2
IMAGE=450769122572.dkr.ecr.us-east-1.amazonaws.com/splunk-for-test:${VERSION}
IMAGE_LOCAL=splunk-for-test:${VERSION}

PORTS="-p 8000:8000 -p 8089:8089 -p 8191:8191 -p 12300:12300 -p 12301:12301 -p 12302:12302 -p 12303:12303 -p 12304:12304 -p 12305:12305 -p 1514:1514 -p 8088:8088 \
       -p 8200:8200 -p 8289:8289 -p 8391:8391 -p 12500:12500 -p 12501:12501 -p 12502:12502 -p 12503:12503 -p 12504:12504 -p 12505:12505 -p 1714:1714 -p 8288:8288"

VOLUME="-v ${PWD}/test/config/props.conf:/opt/splunk_tcp/etc/system/local/props.conf \
        -v ${PWD}/test/config/props.conf:/opt/splunk_ssl/etc/system/local/props.conf \
        -v ${PWD}/test/config/inputs.tcp.conf:/opt/splunk_tcp/etc/apps/search/local/inputs.conf \
        -v ${PWD}/test/config/inputs.ssl.conf:/opt/splunk_ssl/etc/apps/search/local/inputs.conf"

if [ "$VERSION" = "6.3.9" ]; then
  VOLUME="${VOLUME} \
          -v ${PWD}/test/config/server.conf.6.3:/opt/splunk_ssl/etc/system/local/server.conf.original \
          -v ${PWD}/test/config/entrypoint.sh.6.3:/sbin/entrypoint.sh"

fi

case "$COMMAND" in
  pull)
    docker pull ${IMAGE}
    ;;
  run)
    docker run -d --entrypoint=/bin/bash ${PORTS} ${VOLUME} ${IMAGE} /sbin/entrypoint.sh
    ;;
  stop)
    docker stop $(docker ps -q --filter ancestor=${IMAGE})
    ;;
  debug_run)
    docker run --entrypoint=/bin/bash ${PORTS} ${VOLUME} ${IMAGE_LOCAL} /sbin/entrypoint.sh
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
    if [ -z "${CI:-}" ]; then
      echo "load_or_pull is available only on CI"
      exit 1
    fi

    CACHE_DIR=~/docker
    CACHE_IMAGE=${CACHE_DIR}/image-${VERSION}.tar
    if [[ -e ${CACHE_IMAGE} ]]; then
      docker load -i ${CACHE_IMAGE}
    else
      docker pull ${IMAGE}
      mkdir -p ${CACHE_DIR}; docker save -o ${CACHE_IMAGE} ${IMAGE}
    fi
    ;;
  *)
    echo "Unkowon command"
    exit 1
    ;;
esac
