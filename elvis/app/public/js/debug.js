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
      console.log("All loaded, count=", count, ", stats=", stats);
      var done = count - stats[id].freq;
      $('#count span').text(done);
      setTimeout(function() {
        updateStats(id)
      },
      5000);
    });
  }

  updateStats(11901);
});
