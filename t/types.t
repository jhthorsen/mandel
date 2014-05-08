package MyDocument;
use Mandel::Document;
use Types::Standard ':all';
use Mojo::DOM;

my $PlainString = Type::Tiny->new({
  parent => Str,
  constraint => sub { ! /[<>\n]/ },
  message => sub { "$_ not a plain string" },
});

$PlainString->coercion->add_type_coercions(Str, sub { Mojo::DOM->new($_)->all_text; });

field any => ( isa => Any );
field int => ( isa => Int );
field num => ( isa => Num );
field str => ( isa => Str );
field 'nonetype';
field plain => ( isa => $PlainString );

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

{
  diag "coerce";
  eval { $doc->plain({}) };
  like $@, qr{not a plain string}, 'ref is not a plain string';

  $doc->plain("<p>foo\n<span>bar</span></p>\n");
  is $doc->plain, 'foo bar', 'coerced html';
}

{
  diag 'types by model';
  my @expected = ( 'Any', 'Int', 'Num', 'Str', undef, $PlainString );
  my @fields = map { $_->name } $doc->model->fields;

  is_deeply \@fields, [ 'any', 'int', 'num', 'str', 'nonetype', 'plain' ], 'fields by model';

  for(0..@fields-1) {
    is $doc->model->field($fields[$_])->type_constraint, $expected[$_], "type $fields[$_]"
  }
}

done_testing;
