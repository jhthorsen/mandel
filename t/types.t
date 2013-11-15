package MyDocument;
use Mandel::Document;
use Types::Standard ':all';

field any => ( isa => Any );
field int => ( isa => Int );
field num => ( isa => Num );
field str => ( isa => Str );
field 'nonetype';

package main;
use Mojo::Base -strict;
use Mojo::JSON 'j';
use Test::More;

my $doc = MyDocument->new;

is $doc->any('foobar'), $doc, 'any foobar';

eval { $doc->int('foobar') };
like $@, qr{"Int"}, 'foobar is not Int';

eval { $doc->num('foobar') };
like $@, qr{"Num"}, 'foobar is not Num';

is $doc->str('foobar'), $doc, 'foobar is str';

$doc->num("1.23");
$doc->int("42");
like j($doc->data), qr{\:1\.23}, '1.23 is a number';
like j($doc->data), qr{\:42}, '42 is a number';

subtest 'get types' => sub {
  my @expected = ( 'Any', 'Int', undef, 'Num', 'Str' );
  my @fields = sort { $a cmp $b } @{ $doc->model->fields };
  is_deeply \@fields, [ 'any', 'int', 'nonetype', 'num', 'str' ],
    'got cols by model';
  is $doc->model->field_type( $fields[$_] ), $expected[$_], "got type"
    for ( 0 .. @fields - 1 );
};
done_testing;
