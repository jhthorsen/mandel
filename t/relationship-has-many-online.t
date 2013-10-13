use t::Online;
use Test::More;

plan tests => 9;
my $connection = t::Online->mandel;
my $name = rand;

{
  my $person = $connection->collection('person')->create({});
  my $cats;

  ok !$person->in_storage, 'person not in_storage';
  $person->add_cats({ name => $name }, sub {
    my($person, $err, $cat) = @_;
    ok !$err, 'no error';
    ok $cat->in_storage, 'cat in_storage';
    ok $person->in_storage, 'person in_storage';
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;

  $cats = $person->search_cats({}, { limit => 10 });
  isa_ok $cats, 'Mandel::Collection';
  is_deeply $cats->{query}, { 'person.$id' => $person->id }, 'got correct cat query';
  is_deeply $cats->{extra}, { limit => 10 }, 'got correct cat extra';

  $cats->count(sub {
    my($person, $err, $n) = @_;
    is $n, 1, 'one cat in storage';
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;

  $person->cats(sub {
    my($person, $err, $cats) = @_;
    ok !$err, 'no error';
    #is $cats->[0]->name, $name, 'random name';
    Mojo::IOLoop->stop;
  });
  Mojo::IOLoop->start;
}

$connection->storage->db->command(dropDatabase => 1);
