FROM ruby:3.3.0-alpine3.18
RUN apk update
RUN apk add libpq-dev build-base
WORKDIR /app
COPY Gemfile Gemfile
COPY Gemfile.lock Gemfile.lock
RUN bundle install
COPY . .
