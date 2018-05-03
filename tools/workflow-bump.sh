#!/bin/bash

script="$(dirname "$0")/workflow-bump.sql"
mysql -uroot elvis < "$script"

# vim:ts=2:sw=2:sts=2:et:ft=sh

