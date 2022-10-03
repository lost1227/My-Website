#!/bin/bash

set -e

# docker volume inspect jekyll > /dev/null || exit

if [ "$1" == "create" ]; then
    if [ ! $# -ge 2 ]; then
        echo "Usage: $0 create {name}"
        exit 1
    fi
    docker run -it --rm \
        --mount type=bind,src=${PWD},dst=/srv/jekyll \
        jekyll/jekyll \
        sh -c "chown -R jekyll /usr/gem/ && jekyll new $2"
elif [ ! -f Gemfile ]; then
    echo "Error: could not find Gemfile"
    exit 1
elif [ "$1" == "build" ]; then
    docker run -it --rm \
        --mount type=bind,src=${PWD},dst=/srv/jekyll \
        jekyll/jekyll \
        jekyll build
elif [ "$1" == "serve" ]; then
    docker run -it --rm \
        --mount type=bind,src=${PWD},dst=/srv/jekyll \
        --publish 4000:4000 \
        jekyll/jekyll \
        jekyll serve
elif [ "$1" == "bundle" ]; then
    docker run -it --rm \
        --mount type=bind,src=${PWD},dst=/srv/jekyll \
        jekyll/jekyll \
        bundle ${@:2}
else
    echo "Usage: $0 [create|build|serve|bundle]"
    exit 1
fi
