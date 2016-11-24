#!/bin/bash

indir="/data/newstream/elvis/res"
outdir="/data/newstream/elvis/res-watermarked"
watermark="/opt/lintilla/elvis/app/media/BBC Watermark Approved.png"

rm -rf "$outdir" && bin/watermark.js --watermark "$watermark" --width 10 --height 5 -x 95 -y 95 -a 50 -o "$outdir" "$indir"

# vim:ts=2:sw=2:sts=2:et:ft=sh

