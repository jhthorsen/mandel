package Mandel::Collection;

=head1 NAME

Mandel::Collection - A collection of Mandel documents

=head1 SYNOPSIS

  my $connection = MyModel->new(uri => ...);
  my $persons = $connection->collection('person');

  $persons->count(sub {
    my($persons, $err, $int) = @_;
  });

  # ...

=head1 DESCRIPTION

This class is used to describe a group of mongodb documents.

=cut

use Mojo::Base -base;
use Scalar::Util 'blessed';

=head1 ATTRIBUTES

=head2 connection

An object that inherit from L<Mandel>.

=head2 model

An object that inherit from L<Mandel::Model>.

=cut

has connection => sub { die "connection required in constructor" };
has model => sub { die "model required in constructor" };

has _collection => sub {
  my $self = shift;
  $self->connection->_collection($self->model->collection);
};

has _cursor => sub {
  my $self = shift;
  my $extra = $self->{extra} || {};
  my $cursor = $self->_collection->find;

  $cursor->query($self->{query}) if $self->{query};
  $cursor->$_($extra->{$_}) for keys %$extra;
  $cursor;
};

=head1 METHODS

=head2 all

  $self = $self->all(sub { my($self, $err, $docs) = @_; });

Retrieves all documents from the database that match the given L</search>
query.

=cut

sub all {
  my($self, $cb) = @_;

  $self->_cursor->all(sub {
    my($cursor, $err, $docs) = @_;
    return $self->$cb($err, []) if $err;
    return $self->$cb($err, [ map { $self->_new_document($_, 0) } @$docs ]);
  });

  $self;
}

=head2 create

 $self = $self->create(\%data, sub { my($self, $err, $obj) = @_; });
 $self = $self->create($obj, sub { my($self, $err, $obj) = @_; });

Create an unpopulated instance of a given document. The primary reason to use
this over the normal constructor is for class name resolution and proper
handling of certain document attributes.

This new L<Mandel::Document> object will automatically get saved to mongodb
when it goes out of scope, because L<Mandel::Document/updated> will be set to
true.

=cut

sub create {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my $self = shift;

  $self->_new_document(shift || {}, 1);
}

=head2 count

  $self = $self->count(sub { my($self, $err, $int) = @_; });

Used to count how many documents the current L</search> query match.

=cut

sub count {
  my($self, $cb) = @_;

  $self->_cursor->count(sub {
    my($cursor, $err, $int) = @_;
    $self->$cb($err, $int);
  });

  $self;
}

=head2 distinct

  $self = $self->distinct("field_name", sub { my($self, $err, $value) = @_; });

Get all distinct values for key in this collection.

=cut

sub distinct {
  my($self, $field, $cb) = @_;

  $self->_cursor->distinct($field, sub {
    my($cursor, $err, $values) = @_;
    $self->$cb($err, $values);
  });

  $self;
}

=head2 next

  $self = $self->next(sub { my($self, $err, $obj) = @_; ... });

Fetch next document.

=cut

sub next {
  my($self, $cb) = @_;

  $self->_cursor->next(sub {
    my($cursor, $err, $doc) = @_;
    $self->$cb($err, $doc ? $self->_new_document($doc, 0) : undef);
  });

  $self;
}

=head2 remove

  $self = $self->remove(\%query, \%extra, sub { my($self, $err, $doc) = @_; });

Remove the documents that match the given query.

=cut

sub remove {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my $self = shift;

  $self->_collection->remove(@_, $cb);
  $self;
}

=head2 rewind

  $self = $self->rewind($cb);

Rewind cursor and kill it on the server

=cut

sub rewind {
  my($self, $cb) = @_;

  if($self->{_cursor}) {
    $self->_cursor->rewind(sub {
      $self->$cb($_[1]);
    });
  }
  else {
    $self->$cb('');
  }

  $self;
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

  delete $clone->{_cursor};

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
  my $cursor = $self->_cursor->clone->limit(-1);

  $cursor->next(sub {
    my($cursor, $err, $doc) = @_;
    $self->$cb($err, $doc ? $self->_new_document($doc, 0) : undef);
  });

  $self;
}

sub _new_document {
  my($self, $doc, $updated) = @_;
  my $model = $self->model;

  $model->document_class->new(
    connection => $self->connection,
    model => $model,
    updated => $updated,
    $doc ? (_raw => $doc) : (),
  );
}

=head1 SEE ALSO

L<Mojolicious>, L<Mango>, L<Mandel>

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
