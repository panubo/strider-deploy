#!/usr/bin/env bash

set -e

[ "$DEBUG" == 'true' ] && set -x

# Load Config
[ -f $(basename $0).conf ] && . $(basename $0).conf  # Source config if it exists
[ -f ~/.$(basename $0).conf ] && . ~/.$(basename $0).conf

# Set defaults
for env in `tr '\0' '\n' < /proc/1/environ | grep DEPLOY`; do export $env; done
DEPLOY_UPDATE_INTERVAL=${DEPLOY_UPDATE_INTERVAL:-120}
DEPLOY_USE_VENV=${DEPLOY_USE_VENV:-true}
DEPLOY_VENV_ROOT=${DEPLOY_VENV_ROOT:-/data}

# Expose Etcd variables
for env in `tr '\0' '\n' < /proc/1/environ | grep ETCD`; do export $env; done


function self-update() {
    if [ $(find "$0" -mmin +$DEPLOY_UPDATE_INTERVAL) ]; then
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
    # Create virtualenv if required
    if [ "${DEPLOY_USE_VENV}" == "true" ] && [ ! -f '${DEPLOY_VENV_ROOT}/venv/bin/activate' ]; then
        cd ${DEPLOY_VENV_ROOT}
        curl --silent https://raw.githubusercontent.com/adlibre/python-bootstrap/master/bootstrap.sh | bash -s venv 
    fi

    # Activate if required
    if [ "${DEPLOY_USE_VENV}" == "true" ]; then
        cd ${DEPLOY_VENV_ROOT}
        . venv/bin/activate
    fi

    # Update if required
    if [ $(find "$0" -mmin +$DEPLOY_UPDATE_INTERVAL) ]; then
        echo ">> Updating Environment"
        pip install --upgrade git+https://github.com/panubo/fleet-deploy.git#egg=fleet-deploy
        pip install --upgrade git+https://github.com/panubo/fleet-deploy-atomic#egg=fleet-deploy-atomic
    else
        echo ">> Not updating environment"
    fi
}


function prepare() {
    echo ">> Preparing Checkout"
    if [ -z "$GIT_NAME" ]; then
        echo "ERROR: GIT_NAME not set"
        exit 128
    fi
    if [ -z "$GIT_BRANCH" ]; then
        echo "ERROR: GIT_BRANCH not set"
        exit 128
    fi
    # Force checkout branch
    git checkout --force $GIT_BRANCH
    CHECKOUT_DIR=$(basename $(pwd))
    cd ../..  # into .strider
    mkdir -p git # prepare
    [ -d "git/${GIT_NAME}-${GIT_BRANCH}-tmp/" ] && rm -rf git/${GIT_NAME}-${GIT_BRANCH}-tmp/  # Remove tmp dir if we have a previously failed build
    [ -d "git/${GIT_NAME}-${GIT_BRANCH}-old/" ] && rm -rf git/${GIT_NAME}-${GIT_BRANCH}-old/  # Remove old dir if we have a previously failed build
    git clone --bare data/$CHECKOUT_DIR/ git/${GIT_NAME}-${GIT_BRANCH}-tmp/ # checkout a bare clone
    [ -d "git/${GIT_NAME}-${GIT_BRANCH}/" ] && mv git/${GIT_NAME}-${GIT_BRANCH}/ git/${GIT_NAME}-${GIT_BRANCH}-old/
    mv git/${GIT_NAME}-${GIT_BRANCH}-tmp/ git/${GIT_NAME}-${GIT_BRANCH}/
    rm -rf git/${GIT_NAME}-${GIT_BRANCH}-old/
}


function prepare-wordpress() {
    # Prepare cluster for wordpress deployment
    APP_CODE=${GIT_NAME}-${GIT_BRANCH}
    HOST_DOMAIN=${HOST_DOMAIN:-example.com}
    UNIT_TEMPLATE=${UNIT_TEMPLATE:-'/data/units/wordpress@.service'}
    docker rm --name ${APP_CODE}.init 2> /dev/null || true
    docker run --rm --name ${APP_CODE}.init -v /mnt/data00/${APP_CODE}/:/output/ -e MYSQL_PORT_3306_TCP_ADDR=${DB_HOST} -e MYSQL_ENV_MYSQL_ROOT_PASSWORD=$(etcdctl get /secrets/services/${DB_HOST}/mysql_root_password) -e APP_CODE=${APP_CODE} quay.io/panubo/wordpress-init /output/static.env
    j2 $UNIT_TEMPLATE > /tmp/${APP_CODE}@.service
    fleetctl destroy ${APP_CODE}@.service || true
    fleetctl submit /tmp/${APP_CODE}@.service
    docker rm --name ${APP_CODE}.vulcanize 2> /dev/null || true
    docker run --rm --name ${APP_CODE}.vulcanize -e ETCDCTL_PEERS=$ETCDCTL_PEERS quay.io/panubo/vulcanizer --host ${APP_CODE}.${HOST_DOMAIN} --service-name ${APP_CODE}
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

    # Activate Venv
    [ "$DEPLOY_USE_VENV" == "true" ] && cd ${DEPLOY_VENV_ROOT} && . venv/bin/activate

    # Defaults
    DEPLOY_TAG=${DEPLOY_TAG-${GIT_HASH:0:7}}
    DEPLOY_INSTANCES=${DEPLOY_INSTANCES-2}
    DEPLOY_CHUNKING=${DEPLOY_CHUNKING-${DEPLOY_INSTANCES}}
    DEPLOY_ATOMIC_HANDLER=${DEPLOY_ATOMIC_HANDLER-$(which atomic.py)}

    set -ex

    # Run Deploy
    deploy.py --name ${DEPLOY_UNIT} --instances ${DEPLOY_INSTANCES} --chunking ${DEPLOY_CHUNKING} --tag ${DEPLOY_TAG} --method atomic --atomic-handler ${DEPLOY_ATOMIC_HANDLER} --delay 0
}


function cleanup() {
    echo ">> Cleanup Checkout"
    echo "Branches in work dir: $(git branch -a)"
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
