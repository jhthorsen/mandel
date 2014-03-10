use t::Online;
use Test::More;

plan tests => 10;
my $connection = t::Online->mandel;
my $name = rand;

{
  my $person = $connection->collection('person')->create({});
  my $id;

  ## add_father
  
  # Non-blocking
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
    $id = $father->id;
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;

  $connection->collection('person')->count(sub {
    my($cats, $err, $n) = @_;
    is $n, 2, 'two persons in the database';
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;
  
  # Blocking
  ok $person->father, 'got father';
  isnt $person, $person->father, 'invocant doc';
  $person->father({ name => $name });
  ok $person->father->in_storage, 'father in_storage';
  isnt $person->father->id, $id, 'replaced father';
  

}

$connection->storage->db->command(dropDatabase => 1);
