FROM ruby:2.7.0-alpine3.11

LABEL maintainer "JANOG NETCON"

ENV LANG ja_JP.UTF-8
ENV LC_ALL ja_JP.UTF-8

# Wait for DB and Redis
ENV DOCKERIZE_VERSION v0.6.1
RUN wget -O - https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz | tar xzv -C /usr/local/bin

WORKDIR /usr/src/app

# throw errors if Gemfile has been modified since Gemfile.lock
# RUN bundle config --global frozen 1

# gitはbundler-auditに必要
RUN apk update \
 && apk add --no-cache --virtual .build-dep build-base postgresql-dev \
 && apk add --no-cache git less tzdata postgresql-client \
 && cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime \
 && echo "Asia/Tokyo" > /etc/timezone \
 && apk del tzdata \
 && rm -rf /var/cache/apk/*

RUN gem install bundler

ADD Gemfile /usr/src/app
ADD Gemfile.lock /usr/src/app

# install to default path
RUN bundle install --jobs=4

# build --squashでサイズ減少
# CIが面倒くさいので消さない
# RUN apk del .build-dep

COPY . /usr/src/app
