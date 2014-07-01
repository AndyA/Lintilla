// From https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/keys
if (!Object.keys) {
  Object.keys = (function() {
    'use strict';
    var hasOwnProperty = Object.prototype.hasOwnProperty,
    hasDontEnumBug = !({
      toString: null
    }).propertyIsEnumerable('toString'),
    dontEnums = ['toString', 'toLocaleString', 'valueOf', 'hasOwnProperty', 'isPrototypeOf', 'propertyIsEnumerable', 'constructor'],
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

$(function() {
  var here = new URLParser(window.location.href);

  var img_path = '/asset';
  var state = "idle";
  var margin = 1000;
  var page = 100;
  var current = 0;
  var asset_map = {};
  var ref = {};

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

  function traverseUntil(elt, move, test) {
    var ofs = elt.offset();
    for (;;) {
      var prev = move(elt);
      if (!prev.length) break;
      var pofs = prev.offset();
      if (test(pofs, ofs)) break;
      elt = prev;
      ofs = pofs;
    }

    return elt;

  }

  function searchLeft(elt) {
    return traverseUntil(elt, function(e) {
      return e.prev()
    },
    function(p, o) {
      return p.left >= o.left
    });
  }

  function searchRight(elt) {
    return traverseUntil(elt, function(e) {
      return e.next()
    },
    function(p, o) {
      return p.left <= o.left
    });
  }

  function getJson(url, cb) {
    //    console.log("getJson(" + url + ")");
    $.ajax({
      url: url,
      context: this,
      dataType: 'json',
      global: false,
      success: cb
    });
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

  function makeInfo(info) {
    console.log('info: ', info);
    console.log('ref: ', ref);
    var img = info['var']['info'];
    var full = info['var']['full'];
    var body = '';
    if (info.headline) body += textDiv('headline', info.headline);
    if (info.annotation) body += rawDiv('annotation', info.annotation);
    if (info.origin_date) body += textDiv('origin-date', info.origin_date);
    body += '<dl>';

    var refs = Object.keys(ref).sort();
    for (var i = 0; i < refs.length; i++) {
      var rkey = refs[i];
      var ikey = rkey + '_id';
      if (info[ikey]) {
        body += '<dt>' + htmlEncode(rkey.replace('_', ' ')) + '</dt>';
        body += '<dd>' + htmlEncode(ref[rkey][info[ikey]]) + '</dd>';
      }
    }

    body += '</dl>';

    return '<div class="image-preview"><div><a target="_blank" href="' + full.url //
    + '"><img src="' + img.url + '" width="' //
    + img.width + '" height="' + img.height + '"/></a></div></div>' // 
    + '<div class="info-detail">' + body + '</div>' //
    + '<br class="clear-both" />';
  }

  function scrollTo(elt) {
    var wh = $(window).height(),
    eh = elt.height(),
    eo = elt.offset();
    return eo.top + (eh / 2) - (wh / 2);
  }

  function imageClick(ev) {
    // Image clicked
    var $this = $(this);
    var info = asset_map[$this.attr('src')];

    var pos = $this.offset();
    pos.bottom = pos.top + $this.height();
    pos.right = pos.left + $this.width();

    var cx = (pos.left + pos.right) / 2;
    var cy = (pos.top + pos.bottom) / 2;

    var $eol = searchRight($this);
    var adj = 0;
    $('.detail').each(function() {
      var $this = $(this);
      var dpos = $this.offset();
      if (dpos.top < pos.top) adj += $this.height();
      $this.remove();
    });
    $(window).scrollTop($(window).scrollTop() - adj);

    //    $('.detail').remove();
    var deet = $('<div class="detail">' //
    + '<div class="arrow top" style="left: ' + Math.floor(cx) + 'px"></div>' //
    + '<div class="info-text">' + makeInfo(info) + '</div></div>').click(function() {
      $('.detail').remove();
    });
    $eol.after(deet);
    $('.detail a').click(function(e) {
      e.stopPropagation();
    });
    //.animate({ height: '400px' })
    $("html, body").animate({
      scrollTop: scrollTo(deet) + 'px'
    });
  }

  function addImage($c, info) {
    $c.append($('<img></img>').attr({
      class: 'slice',
      src: info.url,
      width: info.width,
      height: info.height
    }).click(imageClick));
  }

  function addImages(imgs) {
    var $c = $('#content');
    for (var i = 0; i < imgs.length; i++) {
      var info = imgs[i]['var']['slice'];
      addImage($c, info);
      asset_map[info.url] = imgs[i];
    }
  }

  function loadNext() {
    state = 'loading';
    var dsu = setURLArgs(ds, {
      size: page,
      start: current
    });
    //    console.log(dsu);
    getJson(dsu, function(imgs) {
      if (imgs.length) {
        addImages(imgs);
        current += page;
        state = 'idle';
      }
      else {
        state = 'done';
      }
    });
  }

  $(window).scroll(function(ev) {
    if (window.innerHeight + window.scrollY + margin >= document.body.offsetHeight) {
      if (state == 'idle') {
        loadNext();
      }
    }
  });

  loadNext();

  getJson('/data/ref/index', function(idx) {
    for (var i = 0; i < idx.length; i++) {
      (function(name) {
        getJson('/data/ref/' + name, function(rd) {
          ref[name] = rd;
        });
      })(idx[i]);
    }
  });
});
