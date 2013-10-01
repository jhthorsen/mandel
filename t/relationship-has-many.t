use Mojo::Base -strict;
use Mandel ();
use Test::More;

my $connection = Mandel->new;
my $person = $connection->model(person => {})->model('person');
my $cat = $connection->model(cat => {})->model('cat');

ok !$person->document_class->can('cats'), 'person cannot cats()';
ok !$person->document_class->can('add_cat'), 'person cannot add_cat()';
ok !$person->document_class->can('search_cats'), 'person cannot search_cats()';

is $person->add_relationship(has_many => cats => $cat->document_class), $person, 'add_relationship()';
ok $person->document_class->can('cats'), 'person can cats()';
ok $person->document_class->can('add_cat'), 'person can add_cat()';
ok $person->document_class->can('search_cats'), 'person can search_cats()';

done_testing;
