#!/bin/bash

echo 'UPDATE elvis_image SET seq = RAND()' | mysql -uroot elvis

# vim:ts=2:sw=2:sts=2:et:ft=sh

