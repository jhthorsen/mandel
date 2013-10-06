use Mojo::Base -strict;
use Mandel ();
use Test::More;

my $connection = Mandel->new;
my $person = $connection->model(person => {})->model('person');
my $cat = $connection->model(cat => {})->model('cat');

ok !$person->document_class->can('cat'), 'person cannot cat()';

isa_ok $person->relationship(has_one => cat => $cat->document_class)->monkey_patch, 'Mandel::Relationship::HasOne';
ok $person->document_class->can('cat'), 'person can cat()';

done_testing;
