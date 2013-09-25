package MangoModel::Type;

=head1 NAME

MangoModel::Type - Collection Types for MangoModel

=head1 SYNOPSIS

package MyModel::MyType;
use MangoModel::Type 'mytype_collection_name';

=head1 DESCRIPTION

L<MangoModel> is a simplistic model layer using the L<Mango> module to interact with a MongoDB backend. The L<MangoModel> class defines the overall model, including high level interaction.
Individual results, called Types inherit from L<MangoModel::Type>.

=cut

use Mojo::Base 'Mojo::Base';
use Mango::BSON::ObjectID;
use Carp;

=head1 ATTRIBUTES

L<MangoModel> inherits all attributes from L<Mojo::Base> and implements the following new ones.

=over

=item id

  $object_id = $self->id;
  $self = $self->id("507f1f77bcf86cd799439011");
  $self = $self->id(Mango::BSON::ObjectID->new);

Returns the L<Mango::BSON::ObjectID> object for this document.
Will create one if it does not already exist.

This can field can also be set.

=cut

sub id {
  my $self = shift;
  my $raw = $self->_raw;

  if ( @_ ) {
    $self->updated(1);
    $raw->{_id} = ref $_[0] ? $_[0] : Mango::BSON::ObjectID->new($_[0]);
    return $self;
  }

  return $raw->{_id} ||= Mango::BSON::ObjectID->new;
}

=item autosave

When true, if the object goes out of scope, and C<updated> is true, the data will be saved.

=item model

An instance of L<MangoModel>. This is required.

=item updated

When true, if the object goes out of scope, and C<autosave> is true, the data will be saved.

=back

=cut

has autosave => 1;
has model    => sub { croak 'Must have a model object reference' };
has updated  => 0;

# holds the raw data
has _raw => sub { {} };

=head1 IMPORTING AND EXPORTED FUNCTIONS

Type definition subclasses should import the base class with an argument which is the collection name to be connected to in the MongoDB database (see the L</SYNOPSIS>). This imports the C<has> attribute creator from L<Mojo::Base> as well as the F<field> creator which defines an accessor method for that field connected to the stored data. Note that as yet no default values are possible and values may not be passed to the constructor; the accessors are the only way to get and set these values.

=cut

sub import {
  my $caller = caller;
  {
    no strict 'refs';
    *{"${caller}::field"} = \&_field;
    if ( @_ > 1 ) { # arg to import is collection name
      my $collection = pop;
      *{"${caller}::collection"} = sub { $collection };
    }
  }
  push @_, __PACKAGE__;
  goto &Mojo::Base::import;
}

=head1 METHODS

L<MangoModel::Type> inherits all of the methods from L<Mojo::Base> and implements the following new ones.

=head2 new

Constructs a new object.

=cut

sub new {
  my $self = shift->SUPER::new(@_);
  $self->id(delete $self->{id}) if $self->{id};
  $self;
}

=over

=item initialize

A no-op placeholder useful for initialization (see C<initialize_types> in L<MangoModel>).

=item collection

This (static) method should provide the name of the collection that Mango uses to store the data. This may be set by the C<import> method. The default implementation will die.

=item save

This method stores the raw data in the database and collection. It also sets C<updated> to false. C<save> is automatically called when the object goes out of scope if and only if C<autosave> and C<updated> are both true.

=back

=cut

sub initialize {}

sub _field {
  my $field = shift;
  my $caller = caller;
  no strict 'refs';
  *{"${caller}::$field"} = sub { shift->_field_accessor( $field => @_ ) };
}

sub _field_accessor {
  my $self = shift;
  my $key = shift;
  my $raw = $self->_raw;

  # raw setter
  if ( @_ ) {
    $self->updated(1);
    $raw->{$key} = shift;
    return $self;
  } 

  return $raw->{$key};
}

sub collection { croak 'collection must be overloaded by subclass' }

# returns a Mango::Collection object for the named collection, perhaps this should be a public method
sub _collection { 
  my $self = shift;
  $self->model->mango->db->collection($self->collection);
}

sub save {
  my($self, $cb) = @_;

  if($cb) {
    $self->_collection->save($self->_raw, sub {
      my($collection, $err, $doc);
      $self->updated(0) if !$err;
      $self->$cb($err);
    });
  }
  else {
    $self->_collection->save($self->_raw);
    $self->updated(0);
  }

  $self;
}

sub DESTROY {
  my $self = shift;
  $self->save if $self->autosave && $self->updated;
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

