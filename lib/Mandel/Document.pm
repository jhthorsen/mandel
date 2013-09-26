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
use Mandel::Description;
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

=head2 autosave

When true, if the object goes out of scope, and L</updated> is true, the data
will be saved.

=head2 model

An instance of L<Mandel>. This is required.

=head2 updated

When true, if the object goes out of scope, and L</autosave> is true, the data
will be saved.

=cut

has autosave => 1;
has model => sub { croak 'Must have a model object reference' };
has updated => 0;

has _collection => sub {
  my $self = shift;
  $self->model->mango->db->collection($self->description->collection);
};

has _raw => sub { +{} }; # raw mongodb document data

=head1 METHODS

L<Mandel::Document> inherits all of the methods from L<Mojo::Base> and
implements the following new ones.

=head2 description

Returns a L<Mandel::Description> object. This object is a class variable and
therefor shared between all instances.

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

  $self = $self->remove(sub { my($self, $err) = @_; })

Will remove this object from the L</collection>, set L</autosave> to 0 and
L</updated> to 1.

=cut

sub remove {
  my($self, $cb) = @_;

  $self->_collection->remove({ _id => $self->id }, sub {
    my($collection, $err, $doc);
    $self->updated(1)->autosave(0) if $doc->{n};
    $self->$cb($err);
  });

  $self;
}

=head2 save

This method stores the raw data in the database and collection. It also sets
L</updated> to false. L</save> is automatically called when the object goes out
of scope if and only if L</autosave> and L</updated> are both true.

=cut

sub save {
  my($self, $cb) = @_;

  $self->id; # make sure we have an ObjectID

  $self->_collection->save($self->_raw, sub {
    my($collection, $err, $doc);
    $self->updated(0) unless $err;
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
  my $description = Mandel::Description->new(document_class => $caller);

  unless($collection) {
    $collection = Mojo::Util::decamelize(($caller =~ /(\w+)$/)[0]);
    $collection .= 's' unless $collection =~ /s$/;
  }

  $description->collection($collection);

  Mojo::Util::monkey_patch($caller, description => sub { $description });
  Mojo::Util::monkey_patch($caller, field => sub { $description->add_field(@_) });
  Mojo::Util::monkey_patch($caller, has_many => sub { $description->add_relationship(has_many => @_) });
  Mojo::Util::monkey_patch($caller, has_one => sub { $description->add_relationship(has_one => @_) });

  @_ = ($class, __PACKAGE__);
  goto &Mojo::Base::import;
}

sub DESTROY {
  my $self = shift;
  $self->save if $self->autosave and $self->updated;
}

=head1 SEE ALSO

L<Mojolicious>, L<Mango>, L<Mandel>

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=cut

1;
