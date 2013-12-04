$(function() {
  var here = new URLParser(window.location.href);

  var img_path = '/asset/elvis';

  function getJson(url, cb) {
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

  function imageURL(kinds, img, variant) {
    var kind = kinds[img.kind_id];
    if (!variant || variant == 'full') return img_path + '/' + kind + '/' + img.acno + '.jpg';
    return img_path + '/' + kind + '/var/' + variant + '/' + img.acno + '.jpg';
  }

  var loaded = new Join(function() {});

  getJson('/data/ref/kind', function(kinds) {
    getJson('/data/page/50/0', function(imgs) {
      var $c = $('#content');
      for (var i = 0; i < imgs.length; i++) {
        var iurl = imageURL(kinds, imgs[i], 'slice');
        $c.append($('<img></img>').attr({
          class: 'slice',
          src: iurl
        }));
      }
    });
  });

});
