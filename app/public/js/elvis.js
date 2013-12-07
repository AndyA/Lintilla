$(function() {
  var here = new URLParser(window.location.href);

  var img_path = '/asset';
  var recipe;
  var state = "idle";
  var margin = 300;
  var page = 50;
  var current = 0;
  var ref = {};

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
    console.log("getJson(" + url + ")");
    $.ajax({
      url: url,
      context: this,
      dataType: 'json',
      global: false,
      success: cb
    });
  }

  function addImage($c, info) {
    $c.append($('<img></img>').attr({
      class: 'slice',
      src: info.url,
      width: info.width,
      height: info.height
    }).click(function(ev) {
      // Image clicked
      console.log("clicked, this=", this, ", ev=", ev);
      var $this = $(this);
      var $eol = searchRight($this);
      $('.detail').remove();
      $eol.after($('<div>Boo!</div>').attr({
        class: 'detail'
      }));
    }));
  }

  function addImages(imgs) {
    var $c = $('#content');
    for (var i = 0; i < imgs.length; i++) {
      addImage($c, imgs[i]['var']['slice']);
    }
  }

  function loadNext() {
    state = 'loading';
    getJson('/data/page/' + page + '/' + current, function(imgs) {
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

  getJson('/data/recipe', function(r) {
    recipe = r;
    loadNext();
  });

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
