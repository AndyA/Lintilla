#!/bin/bash

while sleep 10; do
  perl tools/spider.pl spider gateway.json
done

# vim:ts=2:sw=2:sts=2:et:ft=sh

