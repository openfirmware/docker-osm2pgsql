# DOCKER-VERSION 1.2.0
# VERSION 0.1

FROM debian:wheezy
MAINTAINER James Badger <james@jamesbadger.ca>

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -y git-core

RUN apt-get update && apt-get install -y autoconf automake libtool make g++ \
  libboost-dev libboost-system-dev libboost-filesystem-dev libboost-thread-dev \
  libxml2-dev libgeos-dev libgeos++-dev libpq-dev libbz2-dev libproj-dev \
  protobuf-c-compiler libprotobuf-c0-dev lua5.2 liblua5.2-dev

ENV HOME /root

RUN mkdir src &&\
    cd src &&\
    git clone https://github.com/openstreetmap/osm2pgsql.git &&\
    cd osm2pgsql &&\
    ./autogen.sh &&\
    ./configure &&\
    make &&\
    make install

ENTRYPOINT ["/bin/bash"]
