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
  var img_path = '/asset';
  var state = "idle";
  var margin = 1000;
  var page = 100;
  var current = 0;
  var asset_map = {};
  var ref = {};
  var ref_loaded = false;

  var target = window.location.hash;
  target = target.length > 1 ? target.substr(1) : null;

  function removeHash() {
    var path = window.location.pathname + window.location.search;
    window.history.pushState("", document.title, path);
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
    return $.ajax({
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
    var img = info['var']['display_high'];
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

    return '<div class="picture">' //
    + '<a target="_blank" href="' + full.url + '">' //
    + '<div class="picture-wrapper">' //
    + '<img src="' + img.url + '"/>' //
    + '<span class="wtag fa fa-search-plus fa-2x"></span>' //
    + '</div>' //
    + '</a>' //
    + '</div>' //
    + '<div class="text">' //
    + '<span class="btag">' //
    + '<span class="left fa fa-arrow-circle-o-left fa-2x"></span>' //
    + '<span class="right fa fa-arrow-circle-o-right fa-2x"></span>' //
    + '<span class="close fa fa-times-circle-o fa-2x"></span>' //
    + '</span>' //
    + body //
    + '</div>';
  }

  function scrollTo(elt) {
    var wh = $(window).height(),
    eh = elt.height(),
    eo = elt.offset();
    return eo.top + (eh / 2) - (wh / 2);
  }

  function stepUsing(f) {
    var $curr = $('.selected');
    if ($curr.length) {
      var $next = f($curr);
      while ($next.hasClass('detail')) {
        $next = f($next);
      }
      if ($next.length) imageClick.apply($next[0]);
    }
    else {
      var $next = $('.slice:first');
      if ($next.length) imageClick.apply($next[0]);
    }
  }

  function goLeft() {
    stepUsing(function(e) {
      return e.prev()
    });
  }

  function goRight() {
    stepUsing(function(e) {
      return e.next()
    });
  }

  function closeDetail() {
    $('.selected').removeClass('selected');
    $('.detail').animate({
      height: 'toggle',
      opacity: 'toggle'
    },
    {
      complete: function() {
        removeHash();
        $(this).remove()
      }
    });
  }

  function killDetail(pos) {
    var adj = 0;
    $('.detail').each(function() {
      var $this = $(this);
      var dpos = $this.offset();
      if (dpos.top < pos.top) adj += $this.height();
      $this.remove();
    });
    if (adj) $(window).scrollTop($(window).scrollTop() - adj);
  }

  function imageClick() {
    // Image clicked
    var $this = $(this);
    if ($this.hasClass('selected')) {
      closeDetail();
      return;
    }
    var src = $this.attr('src');
    var info = asset_map[src];
    window.location.hash = src;

    $('.selected').removeClass('selected');
    $this.addClass('selected');

    var pos = $this.offset();
    pos.bottom = pos.top + $this.height();
    pos.right = pos.left + $this.width();

    var cx = (pos.left + pos.right) / 2;
    var cy = (pos.top + pos.bottom) / 2;

    var $eol = searchRight($this);
    killDetail(pos);

    var deet = $('<div class="detail">' //
    + '<div class="arrow top" style="left: ' + Math.floor(cx) + 'px"></div>' //
    + '<div class="floater clearfix">' + makeInfo(info) + '</div></div>');
    $eol.after(deet);
    $('.detail .close').click(closeDetail);
    $('.detail .left').click(goLeft);
    $('.detail .right').click(goRight);
    $('.detail a').click(function(e) {
      e.stopPropagation();
    });
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

  function tryTarget() {
    if (ref_loaded && target && asset_map[target]) {
      var img = $("img[src='" + target + "']")[0];
      imageClick.apply(img);
      target = null;
    }
  }

  function loadNext() {
    state = 'loading';
    var dsu = setURLArgs(ds, {
      size: page,
      start: current
    });

    getJson(dsu, function(imgs) {
      if (imgs.length) {
        addImages(imgs);
        current += page;
        state = 'idle';
        tryTarget();
      }
      else {
        state = 'done';
        if (current == 0) {
          $('#content').append('<div class="notfound">' //
          + '<img src="/images/notfound.jpg" /></div>');
        }
      }
    });
  }

  function resizeHandler() {
    var rtime = null;
    var timeout = false;
    var delta = 500;

    $(window).resize(function() {
      $('.detail').remove();
      rtime = new Date();
      if (!timeout) {
        setTimeout(resizeend, delta);
        timeout = true;
      }
    });

    function resizeend() {
      if (new Date() - rtime < delta) {
        setTimeout(resizeend, delta);
      } else {
        timeout = false;
        var sel = $('.selected');
        if (sel.length) {
          sel.removeClass('selected');
          imageClick.apply(sel[0]);
        }
      }
    }
  }

  $(window).scroll(function(ev) {
    if (window.innerHeight + window.scrollY + margin >= document.body.offsetHeight) {
      if (state == 'idle') {
        loadNext();
      }
    }
  });

  $(document).keyup(function(e) {
    switch (e.keyCode) {
    case 27:
      closeDetail();
      break;
    case 37:
      goLeft();
      break;
    case 39:
      goRight();
      break;
    }
  });

  resizeHandler();
  loadNext();

  getJson('/data/ref/index', function(idx) {
    var defer = [];
    for (var i = 0; i < idx.length; i++) {
      defer.push((function(name) {
        return getJson('/data/ref/' + name, function(rd) {
          ref[name] = rd;
        });
      })(idx[i]));
    }
    $.when.apply($, defer).done(function() {
      ref_loaded = true;
      tryTarget();
    });
  });
});
