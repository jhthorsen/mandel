use t::Online;
use Test::More;

plan tests => 6;
my $connection = t::Online->mandel;
my $name = rand;

{
  my $person = $connection->collection('person')->create({});
  my $id;

  ok !$person->in_storage, 'person not in_storage';
  $person->favorite_cat({ name => $name }, sub {
    my($person, $err, $cat) = @_;
    ok !$err, 'no error';
    ok $cat->in_storage, 'cat in_storage';
    ok $person->in_storage, 'person in_storage';
    $id = $cat->id;
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;

  $person->favorite_cat({ name => $name }, sub {
    my($person, $err, $cat) = @_;
    isnt $cat->id, $id, 'replaced cat';
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;

  $connection->collection('cat')->count(sub {
    my($cats, $n) = @_;
    is $n, 1, 'just one cat in the database';
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;
}

$connection->storage->db->command(dropDatabase => 1);
