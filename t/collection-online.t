use warnings;
use strict;
use Test::More;
use Mandel ();

plan skip_all => 'Set TEST_ONLINE to test' unless $ENV{TEST_ONLINE};
plan tests => 4;

my $db = "mandel_test_$0"; $db =~ s/\W/_/g;
my $connection = Mandel->connect("mongodb://localhost/$db");
my($collection, $iterator);

$connection->model(person => {})->model('person')->add_field('name');
$collection = $connection->collection('person');

$collection->save({ name => 'Bruce' }, sub {
  my($col, $err, $doc) = @_;
  is $col, $collection, 'got collection';
  ok !$err, 'next: no error';
  isa_ok $doc, 'Mandel::Document';
  is $doc->name, 'Bruce', 'saved bruce';
  Mojo::IOLoop->stop;
});
Mojo::IOLoop->start;
