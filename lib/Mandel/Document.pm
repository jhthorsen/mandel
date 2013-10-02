package Mandel::Document;

=head1 NAME

Mandel::Document - A single MongoDB document with logic

=head1 SYNOPSIS

Extend a class with C<MyDocument::Class> instead of L<Mandel::Document>:

  package MyModel::Person;
  use Mandel::Document "MyDocument::Class";

Specify a default collection name, instead of the
L<default|Mandel::Model/collection>. L</import> will think you meant a base
class, if this argument contains "::".

  package MyModel::Person;
  use Mandel::Document "some_collection_name";

Spell out the options with a list:

  package MyModel::Person;
  use Mandel::Document (
    extends => "My::Document::Class",
    collection => "some_collection_name",
    collection_class => "My::Custom::Collection",
  );

=head1 DESCRIPTION

L<Mandel> is a simplistic model layer using the L<Mango> module to interact
with a MongoDB backend. The L<Mandel> class defines the overall model,
including high level interaction. Individual results, called Types inherit
from L<Mandel::Document>.

=cut

use Mojo::Base 'Mojo::Base';
use Mojo::JSON::Pointer;
use Mojo::Util qw( monkey_patch );
use Mandel::Model;
use Mango::BSON::ObjectID;
use Scalar::Util 'looks_like_number';
use Carp 'confess';

my $POINTER = Mojo::JSON::Pointer->new;

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

  if(@_) {
    $self->dirty->{_id} = 1;
    $raw->{_id} = ref $_[0] ? $_[0] : Mango::BSON::ObjectID->new($_[0]);
    return $self;
  }
  elsif($raw->{_id}) {
    return $raw->{_id};
  }
  else {
    $self->dirty->{_id} = 1;
    return $raw->{_id} = Mango::BSON::ObjectID->new;
  }
}

=head2 in_storage

Boolean true if this document has been fetched from storage or L<saved|/save>
to storage.

=head2 connection

An instance of L<Mandel>. This is required.

=head2 model

Returns a L<Mandel::Model> object. This object is a class variable and
therefor shared between all instances.

=head2 dirty

This attribute holds a hash-ref where the keys are name of fields that has
been updated or otherwise not stored in database.

TODO: Define what the values should hold. Timestamp? A counter for how
many times the field has been updated before saved..?

=cut

has connection => sub { confess "connection required in constructor" };
has model => sub { confess "model required in constructor" };
has dirty => sub { +{} };
has in_storage => 0;

has _collection => sub {
  my $self = shift;
  $self->connection->_storage_collection($self->model->collection_name);
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

=head2 contains

  $bool = $self->get('/json/2/pointer');

Use L<Mojo::JSON::Pointer/contains> to check if a value exists inside the raw
mongodb document.

=cut

sub contains {
  my $self = shift;
  $POINTER->contains($self->_raw, @_);
}

=head2 get

  $any = $self->get('/json/2/pointer');

Use L<Mojo::JSON::Pointer/get> to retrieve a value inside the raw mongodb
document.

=cut

sub get {
  my $self = shift;
  $POINTER->get($self->_raw, @_);
}

=head2 is_changed

Returns true if L</dirty> contains any field names.

=cut

sub is_changed {
  return 0 unless $_[0]->{dirty};
  return 0 unless keys %{ $_[0]->{dirty} };
  return 1;
}

=head2 remove

  $self = $self->remove(sub { my($self, $err) = @_; });

Will remove this object from the L</collection> and set mark
all fields as L</dirty>.

=cut

sub remove {
  my($self, $cb) = @_;

  $self->_collection->remove({ _id => $self->id }, { single => 1 }, sub {
    my($collection, $err, $doc);
    unless($err) {
      $self->dirty->{$_} = 1 for keys %{ $self->_raw };
      $self->in_storage(0);
    }
    $self->$cb($err);
  });

  $self;
}

=head2 save

  $self = $self->save(sub { my($self, $err) = @_; });

This method stores the raw data in the database and collection. It clear
the L</dirty> attribute.

NOTE: This method will call the callback (with $err set to empty string)
immediately unless L</is_changed> is true and L</in_storage> is false.

=cut

sub save {
  my($self, $cb) = @_;

  if(!$self->is_changed and $self->in_storage) {
    $self->$cb('');
    return $self;
  }

  $self->id; # make sure we have an ObjectID

  $self->_collection->save($self->_raw, sub {
    my($collection, $err, $doc);
    unless($err) {
      delete $self->{dirty};
      $self->in_storage(1);
    }
    $self->$cb($err);
  });

  $self;
}

=head2 set

  $self = $self->set('/json/2/pointer', $val);

Use a JSON pointer to set data in the raw mongodb document. This method will
die if the pointer points to non-compatible data.

=cut

sub set {
  my($self, $pointer, $val) = @_;
  my $raw = $self->_raw;
  my(@path, $field);

  return $self unless $pointer =~ s!^/!!;
  @path = split '/', $pointer;
  $field = $path[0];

  while(@path) {
    my $p = shift @path;
    my $type = ref $raw;
    my $want = looks_like_number $p ? 'INDEX' : 'KEY';

    if($type eq 'HASH') {
      if(@path) {
        $raw = $raw->{$p} ||= looks_like_number $path[0] ? [] : {};
      }
      else {
        $raw->{$p} = $val;
      }
    }
    elsif($type eq 'ARRAY') {
      if($want ne 'INDEX') {
        confess "Cannot set $want in $type for /$pointer ($p)";
      }
      elsif(@path) {
        $raw = $raw->[$p] ||= looks_like_number $path[0] ? [] : {};
      }
      else {
        $raw->[$p] = $val;
      }
    }
    else {
      confess "Cannot set $want in SCALAR for /$pointer ($p)";
    }
  }

  $self->dirty->{$field} = 1 if defined $field;
  $self;
}

=head2 import

See L</SYNOPSIS>.

=cut

sub import {
  my $class = shift;
  my %args = @_ == 1 ? (collection_name => shift, @_) : @_;
  my $caller = caller;
  my $model = Mandel::Model->new(document_class => $caller, %args);
  my $base_class = 'Mandel::Document';

  if($args{collection_name} and $args{collection_name} =~ /::/) {
    $base_class = delete $args{collection_name};
  }
  if(!$args{collection_name}) {
    $args{collection_name} = Mojo::Util::decamelize(($caller =~ /(\w+)$/)[0]);
    $args{collection_name} .= 's' unless $args{collection_name} =~ /s$/;
    $model->collection_name($args{collection_name});
  }

  monkey_patch $caller, belongs_to => sub { $model->add_relationship(belongs_to => @_) };
  monkey_patch $caller, field => sub { $model->add_field(@_) };
  monkey_patch $caller, has_many => sub { $model->add_relationship(has_many => @_) };
  monkey_patch $caller, has_one => sub { $model->add_relationship(has_one => @_) };
  monkey_patch $caller, model => sub { $model };

  @_ = ($class, $base_class);
  goto &Mojo::Base::import;
}

=head1 SEE ALSO

L<Mojolicious>, L<Mango>, L<Mandel>

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=cut

1;
