use Mojo::Base -strict;
use Test::More;
use lib 't/lib';
use Mojo::IOLoop;

use MyModel;

plan skip_all => 'Set TEST_ONLINE to test'
  unless my $uri = $ENV{TEST_ONLINE};

my $model = MyModel->new( uri => $uri );

isa_ok $model, 'MyModel';
isa_ok $model, 'Mandel';
isa_ok $model, 'Mojo::Base';

$model->drop_database;

{
  my $item = $model->create( 'Menu' );
  $item->soup( 'tomato' );
  ok $item->updated, 'new item marked as updated'; 
}

is $model->count( 'Menu' ), 1, 'item inserted';

{
  my $item = $model->find_one( Menu => { soup => 'tomato' } );
  isa_ok $item, 'MyModel::Menu';
  isa_ok $item, 'Mandel::Document';
  isa_ok $item, 'Mojo::Base';
  is $item->soup, 'tomato', 'found item (blocking)';
}

{
  my $item_isa  = 0;
  my $model_isa = 0;
  my $found     = 0;

  $model->find_one( Menu => { soup => 'tomato'}, sub {
    my ($model, $err, $item) = @_;
    $model_isa = $model->isa('MyModel');
    $item_isa  = $item->isa('MyModel::Menu');
    $found     = $item->soup eq 'tomato';
    Mojo::IOLoop->stop;
  });

  Mojo::IOLoop->start;
  ok $item_isa,  'model is correct type';
  ok $model_isa, 'item is correct type';
  ok $found,     'found item (non-blocking)';
}

done_testing;

