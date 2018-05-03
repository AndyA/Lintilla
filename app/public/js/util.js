// From https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/ \
//                   Global_Objects/Object/keys
if (!Object.keys) {
  Object.keys = (function() {
    'use strict';
    var hasOwnProperty = Object.prototype.hasOwnProperty,
    hasDontEnumBug = !({
      toString: null
    }).propertyIsEnumerable('toString'),
    dontEnums = ['toString', 'toLocaleString', 'valueOf', 'hasOwnProperty', //
    'isPrototypeOf', 'propertyIsEnumerable', 'constructor'],
    dontEnumsLength = dontEnums.length;

    return function(obj) {
      if (typeof obj !== 'object' && (typeof obj !== 'function' || obj === null)) {
        throw new TypeError('Object.keys called on non-object');
      }
      var result = [],
      prop,
      i;
      for (prop in obj) {
        if (hasOwnProperty.call(obj, prop)) {
          result.push(prop);
        }
      }
      if (hasDontEnumBug) {
        for (i = 0; i < dontEnumsLength; i++) {
          if (hasOwnProperty.call(obj, dontEnums[i])) {
            result.push(dontEnums[i]);
          }
        }
      }
      return result;
    };
  } ());
}

function getJson(url, cb) {
  return $.ajax({
    url: url,
    context: this,
    dataType: 'json',
    global: false,
    success: cb
  });
}

function setURLArgs(url, parms) {
  var u = new URLParser(url);
  var p = u.part('path').split('/');
  for (var i = 0; i < p.length; i++) {
    var pp = p[i];
    if (pp.substr(0, 1) == ':') {
      var v = parms[pp.substr(1)];
      if (v !== null) p[i] = v;
    }
  }
  u.part('path', p.join('/'));
  return u.toString();
}

function htmlEncode(value) {
  return $('<div/>').text(value).html();
}

function rawDiv(cl, text) {
  return '<div class="' + cl + '">' + text + '</div>';
}

function textDiv(cl, text) {
  return '<div class="' + cl + '">' + htmlEncode(text) + '</div>';
}

function removeHash() {
  var path = window.location.pathname + window.location.search;
  window.history.pushState("", document.title, path);
}
