# Strider-CD Custom Script

Strider-CD custom script for automated deployments on [Panubo](http://www.panubo.com) managed infrastructure.

This is designed to work with [Fleet Deploy](https://github.com/panubo/fleet-deploy) and [Fleet Deploy Atomic](https://github.com/panubo/fleet-deploy-atomic).

## Installation

This assumes you already have a working [Strider-CD](http://stridercd.com) installation.

1. Create a new project of type custom.
2. Add "Custom Scripts" and "Metadata" plugins.
3. Setup each step in Custom Script plugin: 

#### Environment

```
~/bin/strider.sh self-update
~/bin/strider.sh environment
```

#### Prepare

```
~/bin/strider.sh prepare
```

#### Test

```
~/bin/strider.sh test
```
#### Deploy

AS an example for atomic deployment of two instances, with one new instance created up while another is destroyed.

```
export DEPLOY_INSTANCES=2
export DEPLOY_CHUNKING=1
~/bin/strider.sh deploy
```

#### Cleanup

```
~/bin/strider.sh cleanup $(pwd)
```

4. Configure Metadata plugin:

Key: `GIT_BRANCH` = Value: `ref.branch`
Key: `GIT_NAME` = Value: `project.provider.config.repo`
