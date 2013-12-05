$(function() {
  var here = new URLParser(window.location.href);

  var img_path = '/asset';
  var recipe;
  var state = "idle";
  var margin = 300;
  var page = 50;
  var current = 0;

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

  function boxFit(iw, ih, maxw, maxh) {
    var scale = Math.min(maxw / iw, maxh / ih);
    var sz = [Math.floor(iw * scale), Math.floor(ih * scale)];
    return sz;
  }

  function imageURL(img, variant) {
    if (!variant || variant == 'full') return img_path + '/' + img.hash + '.jpg';
    return img_path + '/var/' + variant + '/' + img.hash + '.jpg';
  }

  function addImages(imgs) {
    var $c = $('#content');
    for (var i = 0; i < imgs.length; i++) {
      var iurl = imageURL(imgs[i], 'slice');
      $c.append($('<img></img>').attr({
        class: 'slice',
        src: iurl
      }));
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

});
