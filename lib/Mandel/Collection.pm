package Mandel::Collection;

=head1 NAME

Mandel::Collection - A grouping of MongoDB documents

=cut

use Mojo::Base -base;
use Scalar::Util 'blessed';

=head1 ATTRIBUTES

=head2 document_class

=head2 model

=cut

has document_class => sub { die "Required in constructor" };
has model => sub { die "Required in constructor" };

has _collection => sub {
  my $self = shift;
  $self->model->mango->db->collection($self->document_class->description->collection);
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

  $self = $self->distinct('field_name', sub { my($self, $err, $value) = @_; });

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

=cut

sub remove {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my $self = shift;

  $self->_collection->remove(@_, $cb);
  $self;
}

=head2 rewind

  $self = $self->rewind;

=cut

sub rewind {
  my $self = shift;
  $self->_cursor->rewind if $self->{_cursor};
  $self;
}

=head2 search

  $clone = $self->search(\%query, \%extra);

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

  $self->document_class->new(
    model => $self->model,
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