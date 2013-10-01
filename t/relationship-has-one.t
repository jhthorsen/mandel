use Mojo::Base -strict;
use Mandel ();
use Test::More;

my $connection = Mandel->new;
my $person = $connection->model(person => {})->model('person');
my $cat = $connection->model(cat => {})->model('cat');

ok !$person->document_class->can('cat'), 'person cannot cat()';

is $person->add_relationship(has_one => cat => $cat->document_class), $person, 'add_relationship()';
ok $person->document_class->can('cat'), 'person can cat()';

$person->add_relationship(has_one => '/favorite/cat' => $cat->document_class);
ok $person->document_class->can('favorite_cat'), 'person can favorite_cat()';

done_testing;
