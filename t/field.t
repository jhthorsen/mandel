package MyDocument;
use Mandel::Document;

field 'foo';
field [qw( bar baz )];

package main;
use Mojo::Base -strict;
use Test::More;

can_ok 'MyDocument', 'foo';
can_ok 'MyDocument', 'bar';
can_ok 'MyDocument', 'baz';

my $doc = MyDocument->new;

is $doc->foo, undef, 'foo is undef';

$doc->data->{bar} = 123;
is $doc->bar, 123, 'bar is 123';

is $doc->baz(42), $doc, 'baz setter return self';
is $doc->baz, 42, 'baz is 42';

is_deeply $doc->TO_JSON, $doc->data, 'TO_JSON() is alias for data()';

done_testing;
