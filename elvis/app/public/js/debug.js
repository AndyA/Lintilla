$(function() {

  var WORKFLOW_TODO = 'RES Unchecked';
  var WORKFLOW_FLAG = 'RES Suitable';

  $.get('/data/keyword/lookup', {
    query: [WORKFLOW_TODO, WORKFLOW_FLAG].join(',')
  }).done(function(tag_to_id) {

    var todo_id = tag_to_id[WORKFLOW_TODO];
    var flag_id = tag_to_id[WORKFLOW_FLAG];

    function updateStats() {
      var count, stats;

      var get_count = $.get('/data/count').done(function(data) {
        count = data * 1;
      });

      var get_stats = $.get('/data/keyword/' + [todo_id, flag_id].join(',')).done(function(data) {
        stats = data;
      });

      $.when(get_count, get_stats).done(function() {
        var todo = stats[todo_id].freq * 1;
        var flag = stats[flag_id].freq * 1;

        var approved = flag - todo;
        var rejected = count - flag;

        $('#count .approved').text(flag - todo);
        $('#count .rejected').text(count - flag);
        $('#count .todo').text(todo);

        setTimeout(function() {
          updateStats()
        },
        5000);
      });
    }

    updateStats();
  });

});
