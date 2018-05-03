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

  function makeMapLink(lat, lon) {
    return 'http://maps.google.com/maps?q=' + lat + ',' + lon;
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

  function makeInfo(info) {
    var img = info['var']['display_high'];
    var full = info['var']['full'];
    var body = '';
    if (info.headline) body += textDiv('headline', info.headline);
    if (info.annotation) body += rawDiv('annotation', info.annotation);
    if (info.origin_date) body += textDiv('origin-date', info.origin_date);
    if (info.latitude && info.longitude) {
      body += rawDiv('map-link', '<a target="_blank" href="' + makeMapLink(info.latitude, info.longitude) + '">map</a>');
    }
    body += '<dl>';

    var refs = Object.keys(ref).sort();
    for (var i = 0; i < refs.length; i++) {
      var rkey = refs[i];
      var ikey = rkey + '_id';
      if (info[ikey]) {
        var link = '/by/' + rkey + '/' + info[ikey];
        body += '<dt>' + htmlEncode(rkey.replace('_', ' ')) + '</dt>';
        body += '<dd><a href="' + link + '">' + htmlEncode(ref[rkey][info[ikey]]) + '</a></dd>';
      }
    }

    var workflow = '';
    if (config.mode == 'workflow') {
      workflow = '<span class="reject fa fa-thumbs-o-down fa-2x"></span>' //
      + '<span class="approve fa fa-thumbs-o-up fa-2x"></span>';
    }

    body += '</dl>';

    return '<div class="picture">' //
    + '<a target="_blank" href="' + full.url + '">' //
    + '<div class="picture-wrapper">' //
    + '<img src="' + img.url + '" width="' + img.width + '" height="' + img.height + '"/>' //
    + '<span class="wtag fa fa-search-plus fa-2x"></span>' //
    + '</div>' //
    + '</a>' //
    + '</div>' //
    + '<div class="text">' //
    + '<span class="btag">' //
    + workflow //
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

  function removeTags(info, ids) {
    return $.post('/svc/tag/remove/' + info.acno + '/' + ids.join(','), {}).fail(function(data) {
      alert("Failed to remove tag");
    });
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

  function goApprove(info) {
    removeTags(info, [config.workflow_id]).done(goRight);
  }

  function goReject(info) {
    removeTags(info, [config.workflow_id, config.mark_id]).done(goRight);
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
    $('.autocomplete-suggestions').remove();
    $('.detail').each(function() {
      var $this = $(this);
      var dpos = $this.offset();
      if (dpos.top < pos.top) adj += $this.height();
    }).remove();
    if (adj) $(window).scrollTop($(window).scrollTop() - adj);
  }

  function makeTag(info) {
    var link = '/tag/' + info.id;
    var tabindex = info.tabindex === null ? '' : ' tabindex="' + info.tabindex + '" ';
    return '<span class="keyword minus">' //
    + '<span ' + tabindex + 'class="keyword-minus fa fa-minus-circle"></span>' //
    + '<a href="' + link + '">' + info.name + '</a>' //
    + '</span>';
  }

  function getLeaf(url) {
    var slash = url.lastIndexOf('/');
    if (slash == -1) return null;
    return url.substr(slash + 1);
  }

  function imageClick() {
    // Image clicked
    var $this = $(this);
    target = null;
    if ($this.hasClass('selected')) {
      closeDetail();
      return;
    }
    var src = $this.attr('src');
    var info = asset_map[src];
    window.history.pushState("", document.title, '#' + src);

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
    $('.detail .reject').click(function() {
      goReject(info)
    });
    $('.detail .approve').click(function() {
      goApprove(info)
    });
    $('.detail a').click(function(e) {
      e.stopPropagation();
    });
    $("html, body").animate({
      scrollTop: scrollTo(deet) + 'px'
    });

    getJson('/data/keywords/' + info.acno, function(kw) {
      var kwl = kw[info.acno];
      var words = [];
      for (var i = 0; i < kwl.length; i++) {
        words.push(makeTag(kwl[i]));
      }
      words.push( //
      '<span class="keyword plus">' //
      + '<form>' //
      + '<span class="keyword-plus fa fa-plus-circle"></span>' //
      + '<input type="text">' //
      + '</form>' //
      + '</span>' //
      );
      $('.detail .text').append($('<div class="keywords">' + words.join('') + '</div>'));

      var kw_remove = function(e) {
        e.stopPropagation();
        var $this = $(this).closest('.keyword');
        var id = getLeaf($this.find('a').attr('href'));
        $.post('/svc/tag/remove/' + info.acno + '/' + id, {}).done(function(data) {
          $this.remove();
        }).fail(function(data) {
          alert("Failed to remove tag");
        })
      };

      var kw_submit = function(e) {
        e.stopPropagation();
        var $this = $(this).closest('.keyword');
        var $input = $this.find('input:first');
        var tag = $input.val();
        $input.val('');
        if (tag.length) {
          $.post('/svc/tag/add/' + info.acno, {
            tag: tag
          }).done(function(data) {
            $this.before($(makeTag(data)));
          }).fail(function(data) {
            alert("Failed to add tag");
          })
          $('.keyword.minus span').click(kw_remove);
        }
        return false;
      };

      $('.keyword.minus span').click(kw_remove);
      $('.keyword.plus span').click(kw_submit);
      $('.keyword form').submit(kw_submit);
      $('.keyword.plus input:first').autocomplete({
        serviceUrl: '/svc/tag/complete/30',
        maxHeight: 10000,
      });
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
      $('.autocomplete-suggestions, .detail').remove();
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
    console.log("KEY: ", e.keyCode);
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

    if (config.mode == 'workflow') {
      switch (e.keyCode) {
      case 78:
        $('.detail .reject').trigger('click');
        break;
      case 89:
        $('.detail .approve').trigger('click');
        break;
      }
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
