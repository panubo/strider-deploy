# Strider-CD Deployment Script

Custom script for automated deployments on [Panubo](http://www.panubo.com) managed infrastructure using [Strider-CD](http://stridercd.com).

This is designed to work in conjunction with [Fleet Deploy](https://github.com/panubo/fleet-deploy) and [Fleet Deploy Atomic](https://github.com/panubo/fleet-deploy-atomic) and this [custom Strider Docker image](https://github.com/macropin/docker-strider).

## Installation

This assumes you already have a working [Strider-CD](http://stridercd.com) installation.

1. Create a new project of type _custom_.
2. Add "Custom Scripts" and "Metadata" plugins.
3. Configure Metadata plugin:
  - Key: `GIT_BRANCH` = Value: `ref.branch`
  - Key: `GIT_NAME` = Value: `project.provider.config.repo`
4. Setup each of the following steps in the _Custom Script_ plugin: 

#### Environment

```
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

As an example for atomic deployment of two instances, with one new instance created up while another is destroyed.

```
export DEPLOY_INSTANCES=2
export DEPLOY_CHUNKING=1
~/bin/strider.sh deploy
```

#### Cleanup

```
~/bin/strider.sh cleanup $(pwd)
```

That's it.