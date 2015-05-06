package Lintilla::Site::Data;

use Moose;

use Dancer ':syntax';
use Dancer::Plugin::Database;

use Lintilla::Data::Model;
use Lintilla::Filter qw( cook );

=head1 NAME

Lintilla::Data - Data handlers

=cut

sub model { Lintilla::Data::Model->new( dbh => database ) }

prefix '/svc' => sub {
  post '/tag/remove/:acno/:id' => sub {
    model->remove_tag( param('acno'), split /,/, param('id') );
  };
  post '/tag/add/:acno' => sub {
    model->get_tag( param('acno'), param('tag') );
  };
  get '/tag/complete/:size' => sub {
    model->tag_complete( param('size'), param('query') );
  };
};

prefix '/data' => sub {
  get '/ref/index' => sub {
    return model->refindex;
  };
  get '/ref/:name' => sub {
    return model->refdata( param('name') );
  };
  get '/page/:size/:start' => sub {
    return cook assets => model->page( param('size'), param('start') );
  };
  get '/tag/:size/:start/:id' => sub {
    return cook assets =>
     model->tag( param('size'), param('start'), param('id') );
  };
  get '/keywords/:acnos' => sub {
    return cook keywords => model->keywords( split /,/, param('acnos') );
  };
  get '/keyword/lookup' => sub {
    my $q = param('query');
    return {} unless defined $q;
    my @name = split /\s*,\s*/, $q;
    return model->get_tag_id(@name);
  };
  get '/keyword/:ids' => sub {
    return model->keyword_info( split /,/, param('ids') );
  };
  get '/count' => sub {
    return model->image_count;
  };
  get '/search/:size/:start' => sub {
    return cook assets =>
     model->search( param('size'), param('start'), param('q') );
  };
  get '/by/:size/:start/:field/:value' => sub {
    return cook assets =>
     model->by( param('size'), param('start'), param('field'),
      param('value') );
  };
  get '/region/:size/:start/:bbox' => sub {
    return cook assets =>
     model->region( param('size'), param('start'), split /,/,
      param('bbox') );
  };
};

1;

# vim:ts=2:sw=2:sts=2:et:ft=perl
