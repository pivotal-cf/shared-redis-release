#!/usr/bin/env bash

set -eu

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( dirname "$DIR" )"

GOPATH="$(mktemp -d)"
mkdir "${GOPATH}/src"
cp -R "${PROJECT_DIR}/src/cf-redis-smoke-tests/vendor/" "${GOPATH}/src/"

pushd "${GOPATH}/src/github.com/onsi/ginkgo"
  GOOS=linux GOARCH=amd64 go build -o "${PROJECT_DIR}/ginkgo"
popd

echo "compiled ginkgo successfully for linux amd64"