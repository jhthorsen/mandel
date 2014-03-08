use t::Online;
use Test::More;

plan tests => 12;
my $connection = t::Online->mandel;
my $person = $connection->collection('person')->create({});
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
    my($person, $err, $cats) = @_;
    ok !$err, 'no error';
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;

  # Blocking
  is ref $person->cats, 'ARRAY', 'array cat docs';
  
}

$connection->storage->db->command(dropDatabase => 1);
