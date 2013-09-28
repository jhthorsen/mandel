use warnings;
use strict;
use Test::More;
use Mandel ();

plan skip_all => 'Set TEST_ONLINE to test' unless $ENV{TEST_ONLINE};
plan tests => 8;

my $db = "mandel_test_$0"; $db =~ s/\W/_/g;
my $connection = Mandel->connect("mongodb://localhost/$db");
my($collection, $id, $iterator);

$connection
  ->model(person => {})
  ->model('person')
  ->add_field([qw/ age name /]);

$collection = $connection->collection('person');

{
  $collection->save({ name => 'Bruce' }, sub {
    my($col, $err, $doc) = @_;
    is $col, $collection, 'got collection';
    ok !$err, 'next: no error';
    isa_ok $doc, 'Mandel::Document';
    is $doc->name, 'Bruce', 'saved bruce';
    $id = $doc->id;
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;
}

{
  $collection->patch({ _id => $id, age => 25 }, sub {
    my($col, $err) = @_;
    is $col, $collection, 'got collection';
    ok !$err, 'next: no error';
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;

  $collection->search({ _id => $id })->single(sub {
    my($col, $err, $doc) = @_;
    is $doc->name, 'Bruce', 'saved name';
    is $doc->age, 25, 'patched age';
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;
}
