#!/usr/bin/env bash

set -e

# Load Config
[ -f "$(dirname $0)/$0.conf" ] && . $(dirname $0)/$0.conf  # Source config if it exists

# Set defaults
UPDATE_INTERVAL=${UPDATE_INTERVAL-120}


function self-update() {
    if [ $(find "$0" -mmin +$UPDATE_INTERVAL) ]; then
        echo ">> Updating $(basename $0)"
        SCRIPT="$(dirname $0)/$(basename $0)"
        curl --silent https://raw.githubusercontent.com/panubo/strider-deploy/master/strider.sh > ${SCRIPT}.tmp
        touch ${SCRIPT}.tmp
        exec bash -c "mv ${SCRIPT}.tmp ${SCRIPT} && chmod +x ${SCRIPT}"
    else
        echo ">> Not Updating $(basename $0)"
    fi
}


function environment() {
    echo ">> Set Environment"
    cd ${VENV_ROOT-/data}
    if [ -f 'venv/bin/activate' ]; then
        if [ $(find "$0" -mmin +$UPDATE_INTERVAL) ]; then
            echo ">> Updating Environment"
            . venv/bin/activate
            pip install --upgrade git+https://github.com/panubo/fleet-deploy.git#egg=fleet-deploy
            pip install --upgrade git+https://github.com/panubo/fleet-deploy-atomic#egg=fleet-deploy-atomic
        else
            echo ">> Not updating environment"
        fi
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
    [ -d "git/${GIT_NAME}-tmp/" ] && rm -rf git/${GIT_NAME}-tmp/  # Remove tmp dir if we have a previously failed build
    [ -d "git/${GIT_NAME}-old/" ] && rm -rf git/${GIT_NAME}-old/  # Remove old dir if we have a previously failed build
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

    # Defaults
    DEPLOY_TAG=${DEPLOY_TAG-${GIT_HASH:0:7}}
    DEPLOY_INSTANCES=${DEPLOY_INSTANCES-2}
    DEPLOY_CHUNKING=${DEPLOY_CHUNKING-${DEPLOY_INSTANCES}}
    DEPLOY_ATOMIC_HANDLER=${DEPLOY_ATOMIC_HANDLER-$(which atomic.py)}

    # Expose ETCD vars
    for env in `tr '\0' '\n' < /proc/1/environ | grep ETCD`; do export $env; done
    # Activate Venv
    cd /data && . venv/bin/activate
    # Run Deploy
    deploy.py --name ${DEPLOY_UNIT} --instances ${DEPLOY_INSTANCES} --chunking ${DEPLOY_CHUNKING} --tag ${DEPLOY_TAG} --method atomic --atomic-handler ${DEPLOY_ATOMIC_HANDLER} --delay 0
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
