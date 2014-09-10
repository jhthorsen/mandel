use t::Online;
use Test::More;

my $connection = t::Online->mandel;
my $name       = rand;
my ($person, $err, $obj, $id, $n);

$connection->storage->db->command(dropDatabase => 1);

{
  my $cat = $connection->collection('cat')->create({});

  # Non-blocking
  ok !$cat->in_storage, 'cat not in_storage';
  $cat->person({name => $name}, sub { (undef, $err, $person) = @_; Mojo::IOLoop->stop; });
  Mojo::IOLoop->start;

  ok !$err, 'no error';
  ok $person->in_storage, 'person in_storage';
  ok $cat->in_storage,    'cat in_storage';
  $id = $person->id;

  ($person, $err, $obj) = (undef, undef, undef);
  $connection->collection('person')->single(
    sub {
      my ($persons, $err, $person) = @_;
      $person->search_cats->single(
        sub {
          (undef, $err, $obj) = @_;
          Mojo::IOLoop->stop;
        }
      );
    }
  );
  Mojo::IOLoop->start;
  is $obj->id, $cat->id, 'found cat';

  $cat->person({name => $name}, sub { (undef, $err, $person) = @_; Mojo::IOLoop->stop; });
  Mojo::IOLoop->start;
  isnt $person->id, $id, 'add new person';
  $id = $person->id;

  $connection->collection('person')->count(sub { (undef, $err, $n) = @_; Mojo::IOLoop->stop; });
  Mojo::IOLoop->start;
  is $n, 2, 'two persons in the database';

  $cat->person(
    sub {
      (undef, $err, $person) = @_;
      Mojo::IOLoop->stop;
    }
  );
  Mojo::IOLoop->start;

  is $person->id, $id, 'got person';
  $id = $person->id;

  # Blocking
  ok $cat->person,     'got person';
  isa_ok $cat->person, 'Mandel::Document::__ANON_1__::Person';
  $cat->person({name => $name});
  ok $cat->person->in_storage, 'person in_storage';
  isnt $cat->person->id, $id, 'replaced person';
}

$connection->storage->db->command(dropDatabase => 1) unless $ENV{KEEP_DATABASE};

done_testing;
