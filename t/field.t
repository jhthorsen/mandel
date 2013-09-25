package MyType;
use MangoModel::Type;

field 'foo';
field [qw( bar baz )];

package main;
use Mojo::Base -strict;
use Test::More;

can_ok 'MyType', 'foo';
can_ok 'MyType', 'bar';
can_ok 'MyType', 'baz';

my $type = MyType->new;

is $type->foo, undef, 'foo is undef';

$type->_raw->{bar} = 123;
is $type->bar, 123, 'bar is 123';

is $type->baz(42), $type, 'baz setter return self';
is $type->baz, 42, 'baz is 42';

done_testing;
