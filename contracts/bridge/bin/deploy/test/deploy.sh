#!/usr/bin/env bash

set -e

Chain0=pangolin
Chain1=goerli

# 0
(from=$Chain0 to=$Chain1 \
. $(dirname $0)/deploy/darwinia.sh)

(from=$Chain1 to=$Chain0
. $(dirname $0)/deploy/ethereum.sh)

#1
(from=$Chain0 to=$Chain1 \
. $(dirname $0)/deploy/darwinia-1.sh)

(from=$Chain1 to=$Chain0
. $(dirname $0)/deploy/ethereum-1.sh)
