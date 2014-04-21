use t::Online;
use Test::More;

my $connection = t::Online->mandel;
my $person = $connection->collection('person')->create({});
my $info = $connection->storage->db->command('buildInfo');
my ($err, $kitten, $kittens);

$connection->storage->db->command(dropDatabase => 1);

$info->{version} ||= 'unknown';

ok !$person->in_storage, 'person not in_storage';

{
  $person->push_kittens({ name => 'nb' }, sub { (undef, $err, $kitten) = @_; Mojo::IOLoop->stop; });
  Mojo::IOLoop->start;
  is $err, '', 'no error';
  ok $kitten->in_storage, 'kitten in_storage';
  ok $person->in_storage, 'person in_storage';

  ($err, $kitten, $kittens) = ();
  $kitten = $person->push_kittens({ name => 'block' });
  ok $kitten->in_storage, 'kitten in storage';

  SKIP: {
    skip "Cannot use \$push and \$position in $info->{version}", 2 unless $info->{version} =~ /^2\.6/;
    $kitten = $person->push_kittens({ name => 'in-between' }, 0);
    is $person->kittens->[0]->id, $kitten->id, 'add kitten first to list';
  }

  is int(@{ $person->data->{kittens} }), 3, 'person has 3 kittens in list';

  ($err, $kitten, $kittens) = ();
  $kittens = $person->search_kittens({}, { limit => 10 });
  isa_ok $kittens, 'Mandel::Collection';
  is_deeply(
    $kittens->{query},
    {
      _id => {
        '$in' => [ map { $_->{'$id'} } @{ $person->data->{kittens} } ],
      },
    },
    'got correct kitten query'
  );
  is_deeply $kittens->{extra}, { limit => 10 }, 'got correct kitten extra';

  my $n;
  $kittens->count(sub { (undef, $err, $n) = @_; Mojo::IOLoop->stop; });
  Mojo::IOLoop->start;
  ok !$err, 'no error';
  is $n, 3, 'kittens in storage: 3';

  $person->kittens(sub { (undef, $err, $kittens) = @_; Mojo::IOLoop->stop; });
  Mojo::IOLoop->start;

  ok !$err, 'no error';
  is scalar(grep { ref($_) =~ /::Cat$/; } @$kittens), 3, 'found 3 kittens';

  is ref $person->kittens, 'ARRAY', 'array kitten docs';
  ok $person->kittens->[0], 'found a kitten';

  is $person->remove_kittens($person->kittens->[0]->id), $person, 'removed kitten';
  is int(@{ $person->data->{kittens} }), 2, 'person has two kitten in list';

  $person->remove_kittens($person->kittens->[0], sub { (undef, $err) = @_; Mojo::IOLoop->stop; });
  Mojo::IOLoop->start;
  is int(@{ $person->data->{kittens} }), 1, 'person has 1 kitten in list';

  is $connection->collection('cat')->count, 3, 'still two kittens in database';
}

$connection->storage->db->command(dropDatabase => 1) unless $ENV{KEEP_DATABASE};

done_testing;
