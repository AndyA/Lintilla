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
