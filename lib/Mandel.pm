package Mandel;

=head1 NAME

Mandel - Simplistic Model Layer for Mango

=head1 SYNOPSIS

  package MyModel;
  use Mojo::Base 'Mandel';

=head1 DESCRIPTION

L<Mandel> is a simplistic model layer using the L<Mango> module to interact
with a MongoDB backend. This class defines the overall model, including high
level interaction. Individual results, called Types inherit from
L<Mandel::Document>.

=head1 WARNING

This code is at BEST alpha quality and anything can and will change or break.
DO NOT USE IN PRODUCTION CODE!

=head1 TODO

I want to replicate L<DBIx::Class> to some extent:
L<DBIx::Class::FilterColumn>,
L<DBIx::Class::InflateColumn>,
L<DBIx::Class::Relationship> and friends,
L<DBIx::Class::ResultSet>,
L<DBIx::Class::ResultSource>,
L<DBIx::Class::Row> and
L<DBIx::Class::Schema>.

=cut

use Mojo::Base 'Mojo::Base';
use Mango;
use Mojo::Loader;
use Carp;

our $VERSION = '0.01';
$VERSION = eval $VERSION;

=head1 ATTRIBUTES

L<Mandel> inherits all attributes from L<Mojo::EventEmitter> and implements
the following new ones.

=head2 mango

An instance of L<Mango> which acts as the database connection. If not
provided, one will be lazily created using the L</uri> attribute.

=head2 namespace

The namespace which will be searched when looking for Types. By default, the
(sub)class name of this module.

=head2 uri

The uri used by L<Mango> to connect to the MongoDB server.

=cut

has mango     => sub { Mango->new( shift->uri or croak 'Please provide a uri' ) };
has namespace => sub { my $self = shift; ref $self or $self };
has uri       => 'mongodb://localhost/mangomodeltest';

=head1 METHODS

L<Mandel> inherits all methods from L<Mojo::Base> and implements the following
new ones.

=head2 initialize

No-op placeholder which is not called by default. This name is reserved for
subclasses to define initialization functions (which it would have to call
itself).

=cut

sub initialize {}

=head2 initialize_types

Takes a list of type names. Calls the C<initialize> method of any type names
passed in or if no names are passed then for all found types.

=cut

sub initialize_types {
  my $self = shift;
  my @types = @_ ? @_ : $self->all_types;

  foreach my $type ( @types ) {
    my $class = $self->class_for($type);
    my $collection = $self->mango->db->collection($class->collection);
    $class->initialize($self, $collection);
  }
}

=head2 all_types

Returns a list of all the types in the L</namespace>.

=cut

sub all_types {
  my $self = shift;
  my $namespace = $self->namespace;
  my $modules = Mojo::Loader->new->search( $namespace );
  return map { my $m = $_; $m =~ s/^${namespace}:://; $m } @$modules;
}

=head2 class_for

Given a type name, find the related class name, ensure that it is loaded (or
else die) and return it.

=cut

sub class_for {
  my ($self, $type) = @_;
  my $class = $self->namespace . '::' . $type;
  if ( !$self->{loaded}{$class} and Mojo::Loader->new->load($class) ) {
    die $@; # rethrow
  }
  $self->{loaded}{$class} = $type;
  $class;
}

=head2 create

 my $head2 = $model->create('Type');
 my $head2 = $model->create('Type', \%mongodb_doc);

Create an unpopulated instance of a given type. The primary reason to use this
over the normal constructor is for class name resolution and proper handling
of certain type attributes.

It is also possible to pass on a C<%mongodb_doc> which will populate all the
L<fields|Mandel::Document/field> defined in the C<Type>.

=cut

sub create {
  my ($self, $type, $raw) = @_;
  $self->_create_from_class( $self->class_for($type), $raw );
}

sub _create_from_class {
  my ($self, $class, $raw) = @_;

  return $class->new(
    model   => $self,
    updated => 1,
    $raw ? (_raw => $raw) : (),
  );
}

=head2 find_one

Takes a type name and a query document. Given that query it performs a
C<find_one> and constructs an instance of that type from the result. If no
result is found then it returns a false value.

=cut

sub find_one {
  my ($self, $type, $query, $cb) = @_;
  my $class = $self->class_for($type);
  my $collection = $self->mango->db->collection($class->collection);
  if ( $cb ) {
    $collection->find_one( $query, sub {
      my ($collection, $error, $doc) = @_;
      my $obj = $self->_create_from_class( $class, $doc );
      $cb->($self, $error, $obj);
    });
    return;
  }
  return unless my $raw = $collection->find_one($query);
  $self->_create_from_class( $class, $raw );
}

=head2 count

Returns the count of documents in the collection associated with a given type
name.

=cut

sub count {
  my ($self, $type) = @_;
  my $class = $self->class_for($type);
  my $collection = $class->collection;
  return $self->mango->db->collection($collection)->find->count;
}

=head2 drop_database

Drops the database that your L<Mango> instance points to. Obviously this
method should be used with care.

=cut

sub drop_database {
  my $self = shift;
  $self->mango->db->command('dropDatabase');
}

=head1 SEE ALSO

L<Mojolicious>, L<Mango>

=head1 SOURCE REPOSITORY

L<http://github.com/jhthorsen/mandel>

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

This project is a fork of L<MangoModel|http://github.com/jberger/MangoModel>,
created by Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Jan Henning Thorsen

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
