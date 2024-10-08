#!/usr/bin/env bash

set -uex

if [ ! -d ".git" ]; then
    git init
    git remote add http https://github.com/fspv/.bashrc.git
    git remote add origin git@github.com:fspv/.bashrc.git
    git fetch http
    git checkout -f http/master
    git checkout master
    git pull http master
fi
