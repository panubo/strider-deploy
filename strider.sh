#!/usr/bin/env bash

set -e


function self-update() {
    echo ">> Updating"
    SCRIPT="$(dirname $0)/$(basename $0)"
    curl --silent https://raw.githubusercontent.com/panubo/strider-deploy/master/strider.sh > ${SCRIPT}.tmp
    exec bash -c "mv ${SCRIPT}.tmp ${SCRIPT} && chmod +x ${SCRIPT}"
}


function environment() {
    echo ">> Set Environment"
    cd ${VENV_ROOT-/data}
    if [ -f 'venv/bin/activate' ]; then
        . venv/bin/activate
        pip install --upgrade git+https://github.com/panubo/fleet-deploy.git#egg=fleet-deploy
        pip install --upgrade git+https://github.com/panubo/fleet-deploy-atomic#egg=fleet-deploy-atomic
    else
        curl --silent https://raw.githubusercontent.com/adlibre/python-bootstrap/master/bootstrap.sh | bash -s venv git+https://github.com/panubo/fleet-deploy.git#egg=fleet-deploy
    fi
}


function prepare() {
    echo ">> Preparing Checkout"
    if [ -z "$GIT_NAME" ]; then
        echo "ERROR: GIT_NAME not set"
        exit 128
    fi
    CHECKOUT_DIR=$(basename $(pwd))
    cd ../..  # into .strider
    mkdir -p git # prepare
    git clone --bare data/$CHECKOUT_DIR/ git/${GIT_NAME}-tmp/ # checkout a bare clone
    [ -d "git/${GIT_NAME}/" ] && mv git/${GIT_NAME}/ git/${GIT_NAME}-old/
    mv git/${GIT_NAME}-tmp/ git/${GIT_NAME}/
    rm -rf git/${GIT_NAME}-old/
}


function test() {
    echo ">> Test Phase"
    /bin/true
}


function deploy() {
    echo ">> Deploying"

    if [ -z "$GIT_NAME" ]; then
        echo "ERROR: GIT_NAME not set"
        exit 128
    fi

    if [ -z "$GIT_BRANCH" ]; then
        echo "ERROR: GIT_BRANCH not set"
        exit 128
    fi

    if [ -z "$DEPLOY_UNIT" ]; then
        DEPLOY_UNIT="${GIT_NAME}-${GIT_BRANCH}"
        echo "Using unit $DEPLOY_UNIT"
    fi

    # Export Git Rev Hash
    export GIT_HASH=$(git rev-parse HEAD)
    # Expose ETCD vars
    for env in `tr '\0' '\n' < /proc/1/environ | grep ETCD`; do export $env; done
    # Activate Venv
    cd /data && . venv/bin/activate
    # Run Deploy
    deploy.py --name ${DEPLOY_UNIT} --instances ${DEPLOY_INSTANCES-2} --chunking ${DEPLOY_CHUNKING-1} --tag ${GIT_HASH:0:7} --method atomic --atomic-handler $(which atomic.py) --delay 0
}


function cleanup() {
    echo ">> Cleanup Checkout"
    DIR=${1-$(pwd)}
    cd ..
    if [ -d "${DIR}/.git" ]; then
        rm -rf "${DIR}"
        echo "Removed ${DIR}"
    else
        echo "ERROR: Refusing to cleanup ${DIR}. Directory not found or non Git directory."
        exit 128
    fi
}


function help() {
    echo "Specify which phase to run <strider.sh> <self-update|environment|prepare|test|deploy|cleanup>"
}


# Show default help. Pass arguments to the function
CMD=${1-help}
shift || true
$CMD $*
