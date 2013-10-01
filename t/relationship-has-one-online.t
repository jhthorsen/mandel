use t::Online;
use Test::More;

plan tests => 6;
my $connection = t::Online->mandel;
my $name = rand;

{
  my $person = $connection->collection('person')->create({});
  my $id;

  ok !$person->in_storage, 'person not in_storage';
  $person->father({ name => $name }, sub {
    my($person, $err, $father) = @_;
    ok !$err, 'no error';
    ok $father->in_storage, 'father in_storage';
    ok $person->in_storage, 'person in_storage';
    $id = $father->id;
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;

  $person->father({ name => $name }, sub {
    my($person, $err, $father) = @_;
    isnt $father->id, $id, 'replaced father';
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;

  $connection->collection('person')->count(sub {
    my($cats, $n) = @_;
    is $n, 2, 'two persons in the database';
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;
}

$connection->storage->db->command(dropDatabase => 1);
