#!/usr/bin/env bash

set -e

function update() {
    echo ">> Updating"
    SCRIPT="$(dirname $0)/$(basename $0)"
    curl --silent https://raw.githubusercontent.com/panubo/strider-deploy/master/strider.sh > ${SCRIPT}.tmp
    exec bash -c "mv ${SCRIPT}.tmp ${SCRIPT} && chmod +x ${SCRIPT}"
}

function environment() {
    echo ">> Set Environment"
    cd ${VENV_ROOT-data}
    if [ -f 'venv/bin/activate' ]; then
        . venv/bin/activate
        pip install --upgrade git+https://github.com/panubo/fleet-deploy.git#egg=fleet-deploy
        pip install --upgrade git+https://github.com/panubo/fleet-deploy-atomic#egg=fleet-deploy-atomic
    else
        curl --silent https://raw.githubusercontent.com/adlibre/python-bootstrap/master/bootstrap.sh | bash -s venv git+https://github.com/panubo/fleet-deploy.git#fleet-deploy
    fi
}


function prepare() {
    echo ">> Preparing Checkout"
    # TODO check for $GIT_NAME
    CHECKOUT_DIR=$(basename $(pwd))
    cd ../..  # into .strider
    mkdir -p git # prepare
    rsync -a --delete data/$CHECKOUT_DIR git/$GIT_NAME # copy our clone
}

function test() {
    echo ">> Test Phase"
    /bin/true
}

function deploy() {
    echo ">> Deploying"
    UNIT="${GIT_NAME}-${GIT_BRANCH}"
    # Export Git Rev
    export GIT_HASH=$(git rev-parse HEAD)
    echo "Git Hash: $GIT_HASH"
    # Expose ETCD vars
    for env in `tr '\0' '\n' < /proc/1/environ | grep ETCD`; do export $env; done
    # Activate Venv
    cd /data && . venv/bin/activate
    # Run Deploy
    deploy.py --name $UNIT --method atomic --instances 2 --chunking 1 --tag ${GIT_HASH:0:7} --delay 0 --atomic-handler $(which atomic.py)
}

function cleanup() {
    echo ">> Cleanup Checkout"
    DIR=$(pwd)
    echo "Removing ${DIR}"
    cd .. && rm -rf "${DIR}"
}

function help() {
    echo "Specify which phase to run <strider.sh> <update|environment|prepare|test|deploy|cleanup>"
}

${1-help}
