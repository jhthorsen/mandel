package Mandel::Model::Field;

=head1 NAME

Mandel::Model::Field - Field meta object

=head1 DESCRIPTION

This class defines meta data for a L<field|Mandel::Model/field> object.

=head1 SYNOPSIS

=head2 Using DSL

  package MyModel::Cat;
  use Mandel::Document;
  use Types::Standard 'Int';

  field age => (isa => Int);
  field "name";
  field "friends";

=head2 Object oriented interface:

  use Types::Standard 'Int';
  MyModel::Cat->model->field(age => (isa => Int));

See also L<Mandel::Model/field>.

=cut

use Mojo::Base -base;

=head1 ATTRIBUTES

=head2 name

  $self = $self->name($str);
  $str = $self->name;

Returns the name of the field.

=head2 type_constraint

  use Types::Standard 'Int';
  $self->type_constraint(Int);
  $type_object = $self->type_constraint;

Returns the type specified as "isa" in the constructor.

The type constraint will also automatically
L<coerce|Type::Tiny/Validation and coercion> if it can.
This feature is experimental! You might have to define
"coerce" as well in the feature:

  field age => (isa => Int, coerce => 1);

=cut

sub name { shift->{name} }
sub type_constraint { shift->{isa} }

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
