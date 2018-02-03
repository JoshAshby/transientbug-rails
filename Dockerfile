FROM ruby:2.4-alpine3.6
LABEL maintainer="Josh Ashby <me@joshisa.ninja>"

ENV PGDATA /var/lib/postgresql/data
ENV LANG en_US.utf8

ENV ELASTICSEARCH_VERSION 5.6.7
ENV ELASTICSEARCH_DOWNLOAD https://artifacts.elastic.co/downloads/elasticsearch

RUN mkdir -p /opt &&\
    adduser -h /opt/elasticsearch -g elasticsearch -s /bin/sh -D elasticsearch &&\
    mkdir -p $PGDATA &&\
    chown postgres $PGDATA &&\
    chmod +rw $PGDATA &&\
    mkdir -p /run/postgresql &&\
    chown postgres /run/postgresql/ &&\
    chmod +rw /run/postgresql/ &&\
    mkdir /app

RUN echo -e 'http://dl-cdn.alpinelinux.org/alpine/edge/main' >> /etc/apk/repositories &&\
    echo -e 'http://dl-cdn.alpinelinux.org/alpine/edge/community' >> /etc/apk/repositories &&\
    echo -e 'http://dl-cdn.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories &&\
    apk add --no-cache --update build-base \
                                postgresql \
                                postgresql-dev \
                                sqlite-dev \
                                cmake \
                                gcc \
                                g++ \
                                git \
                                curl \
                                libuv \
                                libuv-dev \
                                nodejs-current \
                                yarn \
                                python2 \
                                openjdk8-jre \
                                openssl

WORKDIR /opt

RUN ln -s elasticsearch elasticsearch-$ELASTICSEARCH_VERSION &&\
    set -x &&\
    wget -O - "$ELASTICSEARCH_DOWNLOAD/elasticsearch-$ELASTICSEARCH_VERSION.tar.gz" | tar zxvf - &&\
    set -ex \
    && for path in \
        /opt/elasticsearch/data \
        /opt/elasticsearch/logs \
        /opt/elasticsearch/config \
        /opt/elasticsearch/config/scripts \
    ; do \
        mkdir -p "$path"; \
    done ; \
    chown -R elasticsearch:elasticsearch /opt/elasticsearch &&\
    su postgres -c 'pg_ctl -w initdb' &&\
    su postgres -c 'pg_ctl -w start' &&\
    su postgres -c 'createuser --superuser --no-password --createdb docker' &&\
    su postgres -c 'createdb docker'

WORKDIR /app

COPY . .

RUN echo "install: --no-document" > $HOME/.gemrc &&\
    echo "update: --no-document" >> $HOME/.gemrc &&\
    bundle install --jobs 4 &&\
    su elasticsearch -c '/bin/sh /opt/elasticsearch/bin/elasticsearch -d' &&\
    su postgres -c 'pg_ctl -w start' &&\
    bundle exec rake DATABASE_URL=postgresql://docker@127.0.0.1/docker docs:generate assets:precompile
