#!/bin/bash
#
# Copyright 2020 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Adapted from: https://github.com/kubernetes-sigs/iptables-wrappers/blob/master/test/run-test.sh

set -o errexit
set -o nounset
set -o pipefail

if [[ -n "${DEBUG:-}" ]]; then
    set -x
    dash_x="-x"
fi

build_arg=""
build_fail=0
nft_fail=0

while [[ $# -gt 1 ]]; do
    case "$1" in
	--build-arg=*)
	    build_arg="${1#--build_arg=}"
	    ;;
	--build-arg)
	    shift
	    build_arg="$1"
	    ;;
	--build-fail)
	    build_fail=1
	    ;;
	--nft-fail)
	    nft_fail=1
	    ;;
	*)
	    echo "Unrecognized flag '$1'" 1>&2
	    exit 1
	    ;;
    esac
    shift
done

if podman -h &> /dev/null; then
    docker_binary=podman
elif docker -h &> /dev/null; then
    if docker version &> /dev/null; then
	docker_binary=docker
    else
	docker_binary="sudo docker"
	# Get the password prompting out of the way now
	sudo docker version > /dev/null
    fi
else
    echo "Could not find podman or docker" 1>&2
    exit 1
fi

function docker() {
    if [[ -n "${DEBUG:-}" ]]; then
	command ${docker_binary} "$@"
    else
	if [[ "$1" == "build" ]]; then
	    echo "    docker $*"
	fi
	# Redirect stdout to /dev/null and indent stderr
	command ${docker_binary} "$@" 2>&1 > /dev/null | \
	    sed -e '/debconf: delaying package configuration/ d' \
		-e 's/^/    /'
    fi
}

function build() {
    shift

	if ! docker buildx build -t test-hyperkube-base . --load; then
		FAIL "building base image failed"
	fi
	if ! docker buildx build --build-arg IMAGE=test-hyperkube-base -q -t iptables-wrapper-test -f tests/Dockerfile "$@" . --load; then
		FAIL "building test image failed"
	fi
    
}

function PASS() {
    printf "\033[1;92mPASS: $@\033[0m\n\n"
    exit 0
}

function FAIL() {
	echo "update-alternatives configuration:"
	docker run iptables-wrapper-test update-alternatives --query iptables

    printf "\033[1;31mFAIL: $@\033[0m\n" 1>&2

    exit 1
}

if ! build iptables-wrapper-test ${build_arg}; then
    if [[ "${build_fail}" = 1 ]]; then
	PASS "build failed as expected"
    fi
    FAIL "build failed unexpectedly"
fi

if ! docker run --privileged -e iptables_binary=/usr/sbin/iptables iptables-wrapper-test /bin/sh ${dash_x:-} /test.sh legacy; then
    FAIL "failed legacy iptables / new rules test"
fi
if ! docker run --privileged -e iptables_binary=/usr/sbin/iptables iptables-wrapper-test /bin/sh ${dash_x:-} /test.sh nft; then
    FAIL "failed nft iptables / new rules test"
fi
if ! docker run --privileged -e iptables_binary=/usr/sbin/ip6tables iptables-wrapper-test /bin/sh ${dash_x:-} /test.sh legacy; then
    FAIL "failed legacy ip6tables / new rules test"
fi
if ! docker run --privileged -e iptables_binary=/usr/sbin/ip6tables iptables-wrapper-test /bin/sh ${dash_x:-} /test.sh nft; then
    FAIL "failed nft ip6tables / new rules test"
fi

PASS "success"
