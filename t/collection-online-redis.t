use t::Online;
use Test::More;

plan tests => 12;

my $connection = t::Online->redis;
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
