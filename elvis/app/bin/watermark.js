#!/usr/bin/env node

"use strict";

const Getopt = require('node-getopt');
const dir = require('node-dir');
const RSVP = require('rsvp');
const fs = require('fs');
const path = require('path');
const Canvas = require('canvas');
const mkdirp = promisify(require('mkdirp'));

const okExtension = ['.jpeg', '.jpg', '.png'];

let opt = new Getopt([
  ['w', 'watermark=IMAGE', 'The watermark image'],
  ['', 'width=PERCENT', 'Max width of watermark (percent, default: 100)'],
  ['', 'height=PERCENT', 'Max height of watermark (percent, default: 100)'],
  ['x', 'hpos=PERCENT', 'Horizontal position of watermark (percent)'],
  ['y', 'vpos=PERCENT', 'Vertical position of watermark (percent)'],
  ['o', 'output=DIR', 'Output directory (default "watermark")'],
  ['h', 'help', 'Show this help'],
]).bindHelp();

opt.parseSystem();
let config = Object.assign({
  width: 100,
  height: 100,
  hpos: 50,
  vpos: 50,
  output: "watermarked"
}, opt.parsedOption.options);

if (config.watermark === undefined)
  throw new Error("--watermark is a required option");

const df = promisify(dir.files);

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

            let width = parseFloat(config.width) / 100;
            let height = parseFloat(config.height) / 100;
            let hpos = parseFloat(config.hpos) / 100;
            let vpos = parseFloat(config.vpos) / 100;

            let maxw = img.width * width;
            let maxh = img.height * height;

            let scale = Math.min(maxw / iwm.width, maxh / iwm.height);
            let ow = Math.round(iwm.width * scale);
            let oh = Math.round(iwm.height * scale);
            let ox = Math.round((img.width - ow) * hpos);
            let oy = Math.round((img.height - oh) * vpos);

            ctx.drawImage(img, 0, 0);
            ctx.drawImage(iwm, ox, oy, ow, oh);

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

function sleep(n) {
  return new RSVP.Promise(function(resolve, reject) {
    setTimeout(resolve, n);
  });
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
