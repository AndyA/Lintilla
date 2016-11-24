#!/bin/bash

echo 'SELECT hash FROM elvis_image AS i, elvis_image_keyword AS ik ' \
  ' WHERE i.acno=ik.acno AND ik.id=11901 ORDER BY hash' \
  | mysql -uroot elvis | tail -n +2 | perl -pe 's!^(...)(...)(.+)!$1/$2/$3.jpg!'

# vim:ts=2:sw=2:sts=2:et:ft=sh

