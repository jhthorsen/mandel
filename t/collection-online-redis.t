use t::Online;
use Test::More;

plan tests => 6;

my $connection = t::Online->redis;
my $collection = $connection->collection('person');
my($id, $doc);

{
  $collection->save({ name => 'Bruce', age => 30 }, sub {
    my($col, $err) = @_;
    $doc = pop;
    is $col, $collection, 'got collection';
    ok !$err, 'next: no error';
    is $doc->name, 'Bruce', 'saved bruce';
    $id = $doc->id;
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;
}

{
  isa_ok $doc, 'Mandel::Document';
  is $doc->patch({ age => 25 }), $doc, 'patch()';
  is $doc->remove(), $doc, 'remove()';
}
