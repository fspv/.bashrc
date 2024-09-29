#!/usr/bin/env bash

set -uex

if [ ! -d ".git" ]; then
    git init
    git remote add https://github.com/fspv/.bashrc.git
    git pull
fi
