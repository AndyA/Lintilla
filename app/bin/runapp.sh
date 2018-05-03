#!/bin/bash

plackup -R lib,config.yml -s FCGI --nproc 10 --port 9092 bin/app.pl

# vim:ts=2:sw=2:sts=2:et:ft=sh

