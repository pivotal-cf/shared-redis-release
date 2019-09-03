#!/usr/bin/env bash

set -eu

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( dirname "$DIR" )"

export GOPATH=$HOME/go
pushd "$GOPATH"
  GOOS=linux GOARCH=amd64 go build -o "${PROJECT_DIR}/ginkgo" "github.com/onsi/ginkgo/ginkgo"
popd

echo "compiled ginkgo successfully for linux amd64"