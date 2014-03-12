use t::Online;
use Test::More;

plan tests => 12;
my $connection = t::Online->mandel;
my $name = rand;

$connection->storage->db->command(dropDatabase => 1);

{
  my $cat = $connection->collection('cat')->create({});
  my $id;

  # Non-blocking
  ok !$cat->in_storage, 'cat not in_storage';
  $cat->person({ name => $name }, sub {
    my($cat, $err, $person) = @_;
    ok !$err, 'no error';
    ok $person->in_storage, 'person in_storage';
    ok $cat->in_storage, 'cat in_storage';
    $id = $person->id;
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;

  $connection->collection('person')->single(sub {
    my($persons, $err, $person) = @_;
    $person->search_cats->single(sub {
      my($person, $err, $obj) = @_;
      is $obj->id, $cat->id, 'found cat';
      Mojo::IOLoop->stop;
    });
  });
  Mojo::IOLoop->start;

  $cat->person({ name => $name }, sub {
    my($cat, $err, $person) = @_;
    isnt $person->id, $id, 'add new person';
    $id = $person->id;
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;

  $connection->collection('person')->count(sub {
    my($persons, $err, $n) = @_;
    is $n, 2, 'two persons in the database';
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;

  $cat->person(sub {
    my($cat, $err, $person) = @_;
    is $person->id, $id, 'got person';
    $id = $person->id;
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;
  
  # Blocking
  ok $cat->person, 'got person';
  isa_ok $cat->person, 'Mandel::Document::__ANON_1__::Person';
  $cat->person({ name => $name }); 
  ok $cat->person->in_storage, 'person in_storage';
  isnt $cat->person->id, $id, 'replaced person';
  
}

$connection->storage->db->command(dropDatabase => 1);
