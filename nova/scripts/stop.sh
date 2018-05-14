#!/bin/bash

set -e

if [ -f /var/nova/current/tmp/pids/puma.pid ]; then
  su -l ubuntu -c 'kill -s TERM `cat /var/nova/current/tmp/pids/puma.pid`'
fi

if [ -f /var/nova/current/tmp/pids/sidekiq.pid ]; then
  bundle exec sidekiqctl stop /var/nova/current/tmp/pids/sidekiq.pid 180
fi
