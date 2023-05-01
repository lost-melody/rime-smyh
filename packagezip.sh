#!/bin/sh

set -x
cd "$(dirname $0)/schema"

atool -a "/tmp/smyh-$(date '+%Y%m%d-%H%M%S').zip" *
