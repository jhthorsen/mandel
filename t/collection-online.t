use t::Online;
use Test::More;

plan tests => 8;

my $connection = t::Online->mandel;
my $collection = $connection->collection('person');
my($id, $iterator);

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

$connection->storage->db->command(dropDatabase => 1);
