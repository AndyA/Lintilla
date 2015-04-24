$(function() {

  function updateStats(id) {
    var count, stats;
    var get_count = $.get('/data/count').done(function(data) {
      count = data;
    });
    var get_stats = $.get('/data/keyword/' + id).done(function(data) {
      stats = data;
    });
    $.when(get_count, get_stats).done(function() {
      var included = stats[id].freq;
      var excluded = count - included;
      $('#count .included').text(included);
      $('#count .excluded').text(excluded);
      setTimeout(function() {
        updateStats(id)
      },
      5000);
    });
  }

  updateStats(11901);
});
