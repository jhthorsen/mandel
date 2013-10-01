package Mandel::Relationship::HasMany;

=head1 NAME

Mandel::Relationship::HasOne - A field relates to many other mongodb document

=head1 DESCRIPTION

Example:

  MyModel::Cat
    ->description
    ->add_relationship(has_many => owners => 'MyModel::Person');

Will add:

  $cat = MyModel::Cat->new->add_owner(\%args, $cb);
  $cat = MyModel::Cat->new->add_owner($person_obj, $cb);

  $person_obj = MyModel::Cat->new->add_owner(\%args);
  $person_obj = MyModel::Cat->new->add_owner($person_obj);

  $persons = MyModel::Cat->new->search_owners;

  $person_objs = MyModel::Cat->new->owners;
  $self = MyModel::Cat->new->owners(sub {
    my($self, $err, $person_objs) = @_;
  });

=cut

use Mojo::Base 'Mandel::Relationship';
use Mojo::Util;

=head1 METHODS

=head2 create

  $clsas->create($target => $field_name => 'Other::Document::Class');

=cut

sub create {
  my $class = shift;
  my $target = shift;

  Mojo::Util::monkey_patch($target => $class->_other_objects(@_));
  Mojo::Util::monkey_patch($target => $class->_add_other_object(@_));
  Mojo::Util::monkey_patch($target => $class->_search_other_objects(@_));
}

sub _other_objects {
  my($class, $field, $other) = @_;
  my $sub_name = $class->_sub_name($field);
  my $search = "search_$sub_name";

  $field = "/$field" unless $field =~ m!^/!;

  return $sub_name => sub {
    my($self, $cb) = @_;

    $self->$search->all(sub {
      my($collection, $err, $objs) = @_;
      $self->$cb($err, $objs);
    });

    $self;
  };
}

sub _add_other_object {
  my($class, $field, $other) = @_;
  my $sub_name = sprintf 'add_%s', $class->_sub_name($field);

  # Ex: persons => person
  $sub_name =~ s/s$//;
  $field = "/$field" unless $field =~ m!^/!;

  return $sub_name => sub {
    my($self, $obj, $cb) = @_;

    if(ref $obj eq 'HASH') {
      my $model = $class->_load_class($other)->model;
      $obj = $model->collection_class->new({ connection => $self->connection, model => $model })->create($obj);
    }

    Mojo::IOLoop->delay(
      sub {
        my($delay) = @_;
        $obj->save($delay->begin);
      },
      sub {
        my($delay, $err) = @_;
        return $self->$cb($err, $obj) if $err;
        my $ids = $self->get($field) || [];
        push @$ids, $obj->id;
        $self->set($field, $ids)->save($delay->begin);
      },
      sub {
        my($delay, $err) = @_;
        $self->$cb($err, $obj);
      },
    );

    $self;
  };
}

sub _search_other_objects {
  my($class, $field, $other) = @_;
  my $sub_name = sprintf 'search_%s', $class->_sub_name($field);

  $field = "/$field" unless $field =~ m!^/!;

  return $sub_name => sub {
    my($self, $query, $extra) = @_;
    my $ids = $self->get($field) || [];
    my $model = $class->_load_class($other)->model;

    $model->collection_class->new(
      connection => $self->connection,
      model => $model,
      query => {
        %{ $query || {} },
        _id => { '$in' => [ @$ids ] },
      },
      extra => $extra || {},
    );
  };
}

=head1 SEE ALSO

L<Mojolicious>, L<Mango>, L<Mandel::Relationship>

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
