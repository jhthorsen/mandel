package Mandel::Document;

=head1 NAME

Mandel::Document - A single MongoDB document with logic

=head1 SYNOPSIS

  package MyModel::MyType;
  use Mandel::Document 'some_collection_name';

=head1 DESCRIPTION

L<Mandel> is a simplistic model layer using the L<Mango> module to interact
with a MongoDB backend. The L<Mandel> class defines the overall model,
including high level interaction. Individual results, called Types inherit
from L<Mandel::Document>.

=cut

use Mojo::Base 'Mojo::Base';
use Mojo::Util;
use Mango::BSON::ObjectID;
use Mandel::Model;
use Carp;

=head1 ATTRIBUTES

L<Mandel> inherits all attributes from L<Mojo::Base> and implements the
following new ones.

=head2 id

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

  return $raw->{_id} ||= Mango::BSON::ObjectID->new unless @_;
  $self->updated(1);
  $raw->{_id} = ref $_[0] ? $_[0] : Mango::BSON::ObjectID->new($_[0]);
  return $self;
}

=head2 in_storage

Boolean true if this document has been fetched from storage or L<saved|/save>
to storage.

=head2 connection

An instance of L<Mandel>. This is required.

=head2 model

Returns a L<Mandel::Model> object. This object is a class variable and
therefor shared between all instances.

=head2 updated

This attribute is true if any of the mongodb fields has been updated or
otherwise not stored in database.

=cut

has connection => sub { die "connection required in constructor" };
has model => sub { die "model required in constructor" };
has updated => 0;
has in_storage => 0;

has _collection => sub {
  my $self = shift;
  $self->connection->_mango_collection($self->model->collection);
};

has _raw => sub { +{} }; # raw mongodb document data

=head1 METHODS

L<Mandel::Document> inherits all of the methods from L<Mojo::Base> and
implements the following new ones.

=head2 new

Constructs a new object.

=cut

sub new {
  my $self = shift->SUPER::new(@_);
  $self->id(delete $self->{id}) if $self->{id};
  $self;
}

=head2 initialize

A no-op placeholder useful for initialization (see L<Mandel/initialize>)

=cut

sub initialize {}

=head2 remove

  $self = $self->remove(sub { my($self, $err) = @_; });

Will remove this object from the L</collection> and L</updated> to 1.

=cut

sub remove {
  my($self, $cb) = @_;

  $self->_collection->remove({ _id => $self->id }, sub {
    my($collection, $err, $doc);
    unless($err) {
      $self->updated(1);
      $self->in_storage(0);
    }
    $self->$cb($err);
  });

  $self;
}

=head2 save

  $self = $self->save(sub { my($self, $err) = @_; });

This method stores the raw data in the database and collection. It also sets
L</updated> to false.

NOTE: This method will call the callback (with $err set to empty string)
immediately unless L</updated> is set to true.

=cut

sub save {
  my($self, $cb) = @_;

  unless($self->updated) {
    $self->$cb('');
    return $self;
  }

  $self->id; # make sure we have an ObjectID

  $self->_collection->save($self->_raw, sub {
    my($collection, $err, $doc);
    unless($err) {
      $self->updated(0);
      $self->in_storage(1);
    }
    $self->$cb($err);
  });

  $self;
}

=head2 import

See L</SYNOPSIS>.

=cut

sub import {
  my($class, $collection) = @_;
  my $caller = caller;
  my $model = Mandel::Model->new(document_class => $caller);

  unless($collection) {
    $collection = Mojo::Util::decamelize(($caller =~ /(\w+)$/)[0]);
    $collection .= 's' unless $collection =~ /s$/;
  }

  $model->collection($collection);

  Mojo::Util::monkey_patch($caller, field => sub { $model->add_field(@_) });
  Mojo::Util::monkey_patch($caller, has_many => sub { $model->add_relationship(has_many => @_) });
  Mojo::Util::monkey_patch($caller, has_one => sub { $model->add_relationship(has_one => @_) });
  Mojo::Util::monkey_patch($caller, model => sub { $model });

  @_ = ($class, __PACKAGE__);
  goto &Mojo::Base::import;
}

=head1 SEE ALSO

L<Mojolicious>, L<Mango>, L<Mandel>

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=cut

1;
