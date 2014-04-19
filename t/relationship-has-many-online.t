use t::Online;
use Test::More;

my $connection = t::Online->mandel;
my $person = $connection->collection('person')->create({});

$connection->storage->db->command(dropDatabase => 1);

ok !$person->in_storage, 'person not in_storage';

{
  my ($err, $cat, $cats);

  ## add_cats

  # Non-blocking
  $person->add_cats({ name => 'nb' }, sub {
    (undef, $err, $cat) = @_;
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;
  ok !$err, 'no error';
  ok $cat->in_storage, 'cat in_storage';
  ok $person->in_storage, 'person in_storage';

  # Blocking
  ($err, $cat, $cats) = ();
  $cat = $person->add_cats({ name => 'block' });
  ok $cat->in_storage, 'cat in storage';

  ## search_cats

  ($err, $cat, $cats) = ();
  $cats = $person->search_cats({}, { limit => 10 });
  isa_ok $cats, 'Mandel::Collection';
  is_deeply $cats->{query}, { 'person.$id' => $person->id }, 'got correct cat query';
  is_deeply $cats->{extra}, { limit => 10 }, 'got correct cat extra';

  my $n;
  $cats->count(sub {
    (undef, $err, $n) = @_;
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;
  ok !$err, 'no error';
  is $n, 2, 'two cats in storage';

  ## cats

  # Non-blocking
  $person->cats(sub {
    (undef, $err, $cats) = @_;
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;

  ok !$err, 'no error';
  is scalar(grep { ref($_) =~ /::Cat$/; } @$cats), 2, 'found two cats';

  # Blocking
  is ref $person->cats, 'ARRAY', 'array cat docs';
  ok $person->cats->[0], 'found a cat';
}

$connection->storage->db->command(dropDatabase => 1) unless $ENV{KEEP_DATABASE};

done_testing;
