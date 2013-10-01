package
  t::Online;

use Mojo::Base -strict;
use Test::More;
use Mandel ();

sub mandel {
  my $db = "mandel_test_$0"; $db =~ s/\W/_/g;
  my $connection = Mandel->connect("mongodb://localhost/$db");
  my $person = $connection->model(person => {})->model('person');
  my $cat = $connection->model(cat => {})->model('cat');

  $person->add_relationship(has_many => cats => $cat->document_class);
  $person->add_relationship(has_many => '/family/siblings' => $person->document_class);
  $person->add_relationship(has_one => father => $person->document_class);
  $person->add_relationship(has_one => '/favorite/cat' => $cat->document_class);
  $person->add_field([qw/ age name /]);
  $cat->add_field([qw/ type name /]);
  $connection;
}

sub import {
  strict->import;
  warnings->import;
  plan skip_all => 'Set TEST_ONLINE to test' unless $ENV{TEST_ONLINE};
}

1;
