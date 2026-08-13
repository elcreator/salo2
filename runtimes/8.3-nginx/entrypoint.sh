#!/bin/sh
# Two processes, one container. php-fpm goes to the background first: it exits
# non-zero if the pool fails to come up, so a broken PHP config stops the
# container here instead of leaving nginx serving 502s.
set -e

php-fpm --daemonize

exec nginx -g 'daemon off;'
