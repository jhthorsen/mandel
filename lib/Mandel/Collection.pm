package Mandel::Collection;

=head1 NAME

Mandel::Collection - A collection of Mandel documents

=head1 SYNOPSIS

  my $connection = MyModel->connect("mongodb://localhost/my_db");
  my $persons = $connection->collection("person");

  $persons->count(sub {
    my($persons, $err, $int) = @_;
  });

  # ...

=head1 DESCRIPTION

This class is used to describe a group of mongodb documents.

=cut

use Mojo::Base -base;
use Mandel::Iterator;
use Mango::BSON ':bson';
use Scalar::Util 'blessed';
use Carp 'confess';
use constant DEBUG => $ENV{MANDEL_CURSOR_DEBUG} ? eval 'require Data::Dumper;1' : 0;

=head1 ATTRIBUTES

=head2 connection

An object that inherit from L<Mandel>.

=head2 model

An object that inherit from L<Mandel::Model>.

=cut

has connection => sub { confess "connection required in constructor" };
has model => sub { confess "model required in constructor" };

has _storage_collection => sub {
  my $self = shift;
  $self->connection->_storage_collection($self->model->collection_name);
};

=head1 METHODS

=head2 all

  $self = $self->all(sub { my($self, $err, $docs) = @_; });

Retrieves all documents from the database that match the given L</search>
query.

=cut

sub all {
  my($self, $cb) = @_;
  my $delay;

  ($delay, $cb) = $self->_blocking unless $cb;

  $self->_new_cursor->all(sub {
    my($cursor, $err, $docs) = @_;
    return $self->$cb($err, []) if $err;
    return $self->$cb($err, [ map { $self->_new_document($_, 1) } @$docs ]);
  });

  return $delay->wait if $delay;
  return $self;
}

=head2 create

  $document = $self->create;
  $document = $self->create(\%args);

Returns a new object of a given type. This object is NOT inserted into the
mongodb collection. You need to call L<Mandel::Document/save> for that to
happen.

C<%args> is used to set the fields in the new document, NOT the attributes.

=cut

sub create {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my $self = shift;

  $self->_new_document(shift || undef, 0);
}

=head2 count

  $self = $self->count(sub { my($self, $err, $int) = @_; });

Used to count how many documents the current L</search> query match.

=cut

sub count {
  my($self, $cb) = @_;
  my $delay;

  ($delay, $cb) = $self->_blocking unless $cb;
  $self->_new_cursor->count(sub { $self->$cb($_[2]) });

  if($delay) {
    $delay->begin->(''); # hack _blocking() callback
    return $delay->wait;
  }

  return $self;
}

=head2 distinct

  $self = $self->distinct("field_name", sub { my($self, $err, $value) = @_; });

Get all distinct values for key in this collection.

=cut

sub distinct {
  my($self, $field, $cb) = @_;
  my $delay;

  ($delay, $cb) = $self->_blocking unless $cb;

  $self->_new_cursor->distinct($field, sub {
    my($cursor, $err, $values) = @_;
    $self->$cb($err, $values);
  });

  return $delay->wait if $delay;
  return $self;
}

=head2 iterator

  $iterator = $self->iterator;

Returns a L<Mandel::Iterator> object based on the L</search> performed.

=cut

sub iterator {
  my $self = shift;

  Mandel::Iterator->new(
    cursor => $self->_new_cursor,
    model => $self->model,
  );
}

=head2 patch

  $self = $sef->patch(\%document, sub { my($self, $err) = @_ });
  $self = $sef->patch($document, sub { my($self, $err) = @_ });

Used to save of a partial document. This method require
L<_id|Mandel::Document/id> to be set in the document to save.

L</patch> use L<Mandel::Collection/update> with the mongodb C<$set>
operator under the hood.

=cut

sub patch {
  my($self, $patch, $cb) = @_;
  my $id = ref $patch eq 'HASH' ?  delete $patch->{_id} : $patch->id;
  my $delay;

  ($delay, $cb) = $self->_blocking unless $cb;

  unless($id) {
    $self->$cb('_id is required in input $patch');
    return $self;
  }

  $self->_storage_collection->update(
    { _id => ref $id ? $id : bson_oid $id },
    { '$set' => $patch },
    sub {
      my($collection, $err, $doc) = @_;
      $self->$cb($err);
    },
  );

  return $delay->wait if $delay;
  return $self;
}

=head2 remove

  $self = $self->remove(sub { my($self, $err, $doc) = @_; });

Remove the documents that query given to L</search>.

=cut

sub remove {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my $self = shift;
  my $delay;

  ($delay, $cb) = $self->_blocking unless $cb;

  $self->_storage_collection->remove($self->{query}, $cb);

  return $delay->wait if $delay;
  return $self;
}

=head2 save

  $self = $self->save(\%document, sub { my($self, $err, $obj) = @_; );

Used to save a document. The callback receives a L<Mandel::Document>.

=cut

sub save {
  my($self, $raw, $cb) = @_;
  my $delay;

  $raw->{_id} ||= bson_oid;
  ($delay, $cb) = $self->_blocking unless $cb;

  $self->_storage_collection->save($raw, sub {
    my($collection, $err, $doc) = @_;
    $self->$cb($err, $self->_new_document($raw, 1));
  });

  return $delay->wait if $delay;
  return $self;
}

=head2 search

  $clone = $self->search(\%query, \%extra);

Return a clone of the given collection, but with different C<%search> and
C<%extra> parameters. You can chain these calls to make the query more
precise.

C<%extra> will be used to set extra parameters on the L<Mango::Cursor>, where
all the keys need to match the L<Mango::Cursor/ATTRIBUTES>.

=cut

sub search {
  my($self, $query, $extra) = @_;
  my $class = blessed $self;
  my $clone = $class->new(%$self);

  $clone->{extra}{$_} = $extra->{$_} for keys %{ $extra || {} };
  $clone->{query}{$_} = $query->{$_} for keys %{ $query || {} };
  $clone;
}

=head2 single

  $self = $self->single(sub { my($self, $err, $obj) = @_; });

Will return the first object found in the callback, matching the given
C<%search> query.

=cut

sub single {
  my($self, $cb) = @_;
  my $delay;

  ($delay, $cb) = $self->_blocking unless $cb;

  $self->_new_cursor->limit(-1)->next(sub {
    my($cursor, $err, $doc) = @_;
    $self->$cb($err, $doc ? $self->_new_document($doc, 1) : undef);
  });

  return $delay->wait if $delay;
  return $self;
}

sub _blocking {
  my $self = @_;
  my $delay = Mojo::IOLoop->delay;
  my $cb = $delay->begin(0);

  return(
    $delay,
    sub {
      die $_[1] if @_ == 3 and $_[1]; # err
      $cb->($_[2]) if @_ == 3;
      $cb->($_[1]);
    },
  )
}

sub _new_cursor {
  my $self = shift;
  my $extra = $self->{extra} || {};
  my $cursor = $self->_storage_collection->find;

  $cursor->query($self->{query}) if $self->{query};
  $cursor->$_($extra->{$_}) for keys %$extra;
  warn '[', +(caller 1)[3], '] ', Data::Dumper->new([$cursor])->Indent(1)->Sortkeys(1)->Terse(1)->Maxdepth(3)->Dump if DEBUG;
  $cursor;
};

sub _new_document {
  my($self, $doc, $from_storage) = @_;
  my $model = $self->model;
  my @extra;

  if($doc) {
    push @extra, _raw => $doc;
    push @extra, dirty => { map { $_, 1 } keys %$doc };
  }
  if(my $connection = $self->{connection}) {
    push @extra, connection => $connection,
  }

  $model->document_class->new(
    model => $model,
    in_storage => $from_storage,
    @extra,
  );
}

=head1 SEE ALSO

L<Mojolicious>, L<Mango>, L<Mandel>

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
