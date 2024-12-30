#!/bin/bash

echo "$(date -Iseconds) clean $(pwd)" >> /tmp/version.log
sed "s,\"v.*built on.*\",\"DEVELOPMENT_VERSION\",g"
