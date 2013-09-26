package Mandel::Document;

=head1 NAME

Mandel::Document - Collection Types for Mandel

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
use Mango::BSON::ObjectID;
use Mojo::Util;
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

  if ( @_ ) {
    $self->updated(1);
    $raw->{_id} = ref $_[0] ? $_[0] : Mango::BSON::ObjectID->new($_[0]);
    return $self;
  }

  return $raw->{_id} ||= Mango::BSON::ObjectID->new;
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
has model    => sub { croak 'Must have a model object reference' };
has updated  => 0;

# holds the raw data
has _raw => sub { {} };

=head1 IMPORTING AND EXPORTED FUNCTIONS

Type definition subclasses should import the base class with an argument which
is the collection name to be connected to in the MongoDB database (see the
L</SYNOPSIS>). This imports the C<has> attribute creator from L<Mojo::Base> as
well as the F<field> creator which defines an accessor method for that field
connected to the stored data. Note that as yet no default values are possible
and values may not be passed to the constructor; the accessors are the only
way to get and set these values.

=cut

sub import {
  my $caller = caller;
  my $collection = shift;

  unless(defined $collection) {
    $collection = Mojo::Util::decamelize($caller =~ /::(\w+)$/);
    $collection .= 's' unless $collection =~ /s$/;
  }

  Mojo::Util::monkey_patch($caller, field => sub { _field($caller, @_) });
  Mojo::Util::monkey_patch($caller, collection => sub { $collection }) if $collection;
  push @_, __PACKAGE__;
  goto &Mojo::Base::import;
}

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

=head2 collection

This (static) method should provide the name of the collection that Mango uses
to store the data. This may be set by the C<import> method. The default
implementation will die.

=cut

sub collection { croak 'collection must be overloaded by subclass' }

=head2 save

This method stores the raw data in the database and collection. It also sets
L</updated> to false. L</save> is automatically called when the object goes out
of scope if and only if L</autosave> and L</updated> are both true.

=cut

sub save {
  my($self, $cb) = @_;

  if($cb) {
    $self->_collection->save($self->_raw, sub {
      my($collection, $err, $doc);
      $self->updated(0) unless $err;
      $self->$cb($err);
    });
  }
  else {
    $self->_collection->save($self->_raw);
    $self->updated(0);
  }

  $self;
}

# returns a Mango::Collection object for the named collection,
# perhaps this should be a public method
sub _collection {
  my $self = shift;
  $self->model->mango->db->collection($self->collection);
}

sub _field {
  my ($class, $fields) = @_;
  return unless ($class = ref $class || $class) && $fields;

  # Compile fieldibutes
  for my $field (@{ref $fields eq 'ARRAY' ? $fields : [$fields]}) {
    my $code = "package $class;\nsub $field {\n my \$r = \$_[0]->_raw;";
    $code .= "if (\@_ == 1) {\n";
    $code .= "    \$_[0]->{updated}=1;";
    $code .= "    return \$r->{'$field'};";
    $code .= "\n  }\n  \$r->{'$field'} = \$_[1];\n";
    $code .= "  \$_[0];\n}";

    # We compile custom attribute code for speed
    no strict 'refs';
    warn "-- Attribute $field in $class\n$code\n\n" if $ENV{MOJO_BASE_DEBUG};
    Carp::croak "Mandel::Document error: $@" unless eval "$code;1";
  }
}

sub DESTROY {
  my $self = shift;
  $self->save if $self->autosave && $self->updated;
}

=head1 SEE ALSO

L<Mojolicious>, L<Mango>

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=cut

1;
