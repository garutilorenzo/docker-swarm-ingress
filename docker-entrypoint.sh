#!/bin/sh
set -e

(cd ingress && python ingress.py) &
echo $! > /ingress/ingress.pid

exec nginx -g "daemon off;"
