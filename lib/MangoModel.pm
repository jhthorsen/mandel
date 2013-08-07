package MangoModel;

=head1 NAME

MangoModel - Simplistic Model Layer for Mango

=head1 SYNOPSIS

package MyModel;
use Mojo::Base 'MangoModel';

=head1 DESCRIPTION

L<MangoModel> is a simplistic model layer using the L<Mango> module to interact with a MongoDB backend. This class defines the overall model, including high level interaction.
Individual results, called Types inherit from L<MangoModel::Type>. 

=head1 WARNING

This code is at BEST alpha quality and anything can and will change or break. DO NOT USE IN PRODUCTION CODE!!

=cut

use Mojo::Base -base;
use Mango;
use Mojo::Loader;
use Carp;

our $VERSION = '0.01';
$VERSION = eval $VERSION;

=head1 ATTRIBUTES

L<MangoModel> inherits all attributes from L<Mojo::Base> and implements the following new ones.

=over

=item app

An instance of a Mojolicious application. If not provided, one can be lazily created when needed. This is especially useful to have access to helpers.

=item mango

An instance of L<Mango> which acts as the database connection. If not provided, one will be lazily created using the L</uri> attribute.

=item namespace

The namespace which will be searched when looking for Types. By default, the (sub)class name of this module.

=item uri

The uri used by L<Mango> to connect to the MongoDB server.

=back

=cut

has app       => sub { require Mojolicious; Mojolicious->new };
has mango     => sub { Mango->new( shift->uri or croak 'Please provide a uri' ) };
has namespace => sub { my $self = shift; ref $self or $self };
has uri       => 'mongodb://localhost/mangomodeltest';

#sub import {
#  push @_, __PACKAGE__;
#  goto &Mojo::Base::import;
#}

# initialization

=head1 METHODS

L<MangoModel> inherits all methods from L<Mojo::Base> and implements the following new ones.

=head2 Initialization Methods

=over

=item initialize

No-op placeholder which is not called by default. This name is reserved for subclasses to define initialization functions (which it would have to call itself).

=item initialize_types

Takes a list of type names. Calls the C<initialize> method of any type names passed in or if no names are passed then for all found types.

=back

=cut

sub initialize {}

sub initialize_types {
  my $self = shift;
  my @types = @_ ? @_ : $self->all_types;
  foreach my $type ( @types ) {
    my $class = $self->class_for($type);
    my $collection = $self->mango->db->collection($class->collection);
    $class->initialize($self, $collection);
  }
}

=head2 Type and Type Class Helper Methods

=over

=item all_types

Returns a list of all the types in the L</namespace>.

=item class_for

Given a type name, find the related class name, ensure that it is loaded (or else die) and return it.

=item create

 my $item = $model->create('Type');

Create an unpopulated instance of a given type. The primary reason to use this over the normal constructor is for class name resolution and proper handling of certain type attributes.

=item new_class_from_raw

Takes a class name and a hash reference. Given that the hashref which conforms to the fields needed by the type, it constructs an instance of that type. This low-level method is mostly useful for subclasses.

=item new_type_from_raw

Takes a type name and a hash reference. Given that the hashref which conforms to the fields needed by the type, it constructs an instance of that type. This low-level method is mostly useful for subclasses.

=back

=cut

sub all_types {
  my $self = shift;
  my $namespace = $self->namespace;
  my $modules = Mojo::Loader->new->search( $namespace );
  return map { my $m = $_; $m =~ s/^${namespace}:://; $m } @$modules;
}

sub class_for {
  my ($self, $type) = @_;
  my $class = $self->namespace . '::' . $type;
  if ( Mojo::Loader->new->load($class) ) {
    die $@; # rethrow
  }
  return $class;
}

sub create {
  my ($self, $type) = @_;
  my $class = $self->class_for($type);
  my $obj = $class->new(
    model   => $self,
    updated => 1, 
  );
  return $obj;
}

sub new_class_from_raw {
  my ($self, $class, $raw) = @_;
  $class->new(
    _raw  => $raw,
    model => $self,
  );
}

sub new_type_from_raw {
  my ($self, $type, $raw) = @_;
  $self->new_class_from_raw( $self->class_for($type), $raw );
}

=head2 Database Interaction

=over

=item find_one

Takes a type name and a query document. Given that query it performs a C<find_one> and constructs an instance of that type from the result. If no result is found then it returns a false value.

=item count

Returns the count of documents in the collection associated with a given type name.

=item drop_database

Drops the database that your L<Mango> instance points to. Obviously this method should be used with care.

=back

=cut

sub find_one {
  my ($self, $type, $query, $cb) = @_;
  my $class = $self->class_for($type);
  my $collection = $self->mango->db->collection($class->collection);
  if ( $cb ) {
    $collection->find_one( $query, sub {
      $_[2] = $self->new_class_from_raw( $class, $_[2] );
      $cb->(@_);
    });
    return;
  }
  return unless my $raw = $collection->find_one($query);
  $self->new_class_from_raw( $class, $raw );
}

sub count {
  my ($self, $type) = @_;
  my $class = $self->class_for($type);
  my $collection = $class->collection;
  return $self->mango->db->collection($collection)->find->count;
}

sub drop_database {
  my $self = shift;
  $self->mango->db->command('dropDatabase');
}

1;

=head1 SEE ALSO

L<Mojolicious>, L<Mango>

=head1 SOURCE REPOSITORY

L<http://github.com/jberger/MangoModel>

=head1 AUTHOR

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Joel Berger

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
