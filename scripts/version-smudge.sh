#!/bin/bash

git_version="$(git describe --tags --always --match 'v*')"
date="$(date -Iseconds)"
echo "$(date -Iseconds) smudge $(pwd)" >> /tmp/version.log
sed "s,DEVELOPMENT_VERSION,${git_version} built on ${date},g"
