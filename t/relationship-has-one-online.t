use t::Online;
use Test::More;

my $connection = t::Online->mandel;
my $name       = rand;
my ($cat, $err, $id, $n);

$connection->storage->db->command(dropDatabase => 1);

{
  my $dinosaur = $connection->collection('dinosaur')->create({});

  ## add_cat

  # Non-blocking
  ok !$dinosaur->in_storage, 'dinosaur not in_storage';
  $dinosaur->cat({name => $name}, sub { (undef, $err, $cat) = @_; Mojo::IOLoop->stop; });
  Mojo::IOLoop->start;
  ok !$err, 'no error';
  ok $cat->in_storage,      'cat in_storage';
  ok $dinosaur->in_storage, 'dinosaur in_storage';
  $id = $cat->id;

  $dinosaur->cat({name => $name}, sub { (undef, $err, $cat) = @_; Mojo::IOLoop->stop; });
  Mojo::IOLoop->start;
  isnt $cat->id, $id, 'replaced cat';
  $id = $cat->id;

  $connection->collection('dinosaur')->count(sub { (undef, $err, $n) = @_; Mojo::IOLoop->stop; });
  Mojo::IOLoop->start;
  is $n, 1, 'one dinosaur in the database';

  $n = $connection->collection('cat')->count;
  is $n, 1, 'one cat in the database';

  # Blocking
  ok $dinosaur->cat, 'got cat';
  isnt $dinosaur, $dinosaur->cat, 'invocant doc';
  $dinosaur->cat({name => $name});
  ok $dinosaur->cat->in_storage, 'cat in_storage';
  isnt $dinosaur->cat->id, $id, 'replaced cat';
}

$connection->storage->db->command(dropDatabase => 1) unless $ENV{KEEP_DATABASE};

done_testing;
