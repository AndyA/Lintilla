#!/usr/bin/env node

"use strict";

const Canvas = require('canvas');
const Getopt = require('node-getopt');
const RSVP = require('rsvp');
const df = promisify(require('node-dir').files);
const fs = require('fs');
const mkdirp = promisify(require('mkdirp'));
const path = require('path');

const okExtension = ['.jpeg', '.jpg', '.png'];

let opt = new Getopt([
  ['w', 'watermark=IMAGE', 'The watermark image'],
  ['', 'width=PERCENT', 'Max width of watermark (percent, default: 100)'],
  ['', 'height=PERCENT', 'Max height of watermark (percent, default: 100)'],
  ['x', 'hpos=PERCENT', 'Horizontal position of watermark (percent)'],
  ['y', 'vpos=PERCENT', 'Vertical position of watermark (percent)'],
  ['a', 'alpha=PERCENT', 'Alpha blending (percent, default: 100)'],
  ['o', 'output=DIR', 'Output directory (default "watermark")'],
  ['h', 'help', 'Show this help'],
]).bindHelp();

opt.parseSystem();
let config = Object.assign({
  width: 100,
  height: 100,
  hpos: 50,
  vpos: 50,
  alpha: 100,
  output: "watermarked"
}, opt.parsedOption.options);

if (config.watermark === undefined)
  throw new Error("--watermark is a required option");

let wm = loadImage(config.watermark).catch(function(err) {
  console.log("Can't load " + config.watermark + ": ", err);
}).then(function(iwm) {
  for (let arg of opt.parsedOption.argv) {
    df(arg).then(function(files) {
      let prev = sleep(1);
      for (let file of files) {
        let ext = path.extname(file).toLowerCase();
        if (okExtension.indexOf(ext) < 0) continue;
        let out = path.join(config.output, path.relative(arg, file));

        prev = prev.then(function() {
          return loadImage(file).then(function(img) {
            console.log("Watermarking " + file + " as " + out);
            let cvs = new Canvas(img.width, img.height);
            let ctx = cvs.getContext("2d");

            let width = parsePercent(config.width);
            let height = parsePercent(config.height);
            let hpos = parsePercent(config.hpos);
            let vpos = parsePercent(config.vpos);
            let alpha = parsePercent(config.alpha);

            let maxw = img.width * width;
            let maxh = img.height * height;

            let scale = Math.min(maxw / iwm.width, maxh / iwm.height);
            let ow = Math.round(iwm.width * scale);
            let oh = Math.round(iwm.height * scale);
            let ox = Math.round((img.width - ow) * hpos);
            let oy = Math.round((img.height - oh) * vpos);

            ctx.save();
            ctx.drawImage(img, 0, 0);
            ctx.globalAlpha = alpha;
            ctx.drawImage(iwm, ox, oy, ow, oh);
            ctx.restore();

            return mkdirp(path.dirname(out)).then(function() {
              return saveImage(out, cvs);
            }).catch(function(err) {
              console.log("Error: ", err);
              throw new Error(err);
            });

          }).catch(function(err) {
            console.log(err)
          });
        });
      }
    });
  }

});

function parsePercent(x) {
  return parseFloat(x) / 100;
}

function getStream(name, cvs) {
  if (path.extname(name).toLowerCase() === ".png")
    return cvs.pngStream({
      bufsize: 256 * 1024,
    });

  return cvs.jpegStream({
    bufsize: 256 * 1024,
    quality: 90
  });
}

function saveImage(name, cvs) {
  let ostm = fs.createWriteStream(name);
  let istm = getStream(name, cvs);
  return new RSVP.Promise(function(resolve, reject) {
    istm.on('end', resolve);
    istm.on('error', reject);
    istm.pipe(ostm);
  });
}

function loadImage(name) {
  let rf = promisify(fs.readFile);
  return rf(name).then(function(imgData) {
    let img = new Canvas.Image;
    img.src = imgData;
    return img;
  });
}

function sleep(n) {
  return new RSVP.Promise(function(resolve, reject) {
    setTimeout(resolve, n);
  });
}

function promisify(func) {
  return function() {
    let args = [].slice.call(arguments);
    return new RSVP.Promise(function(resolve, reject) {
      args.push(
        function(err, result) {
          if (err) reject(err);
          else resolve(result);
        });
      func.apply(null, args);
    });
  }
}
