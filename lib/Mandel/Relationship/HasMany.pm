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

  $clsas->create($target => $accessor => 'Other::Document::Class');

=cut

sub create {
  my $class = shift;
  my $target = shift;

  Mojo::Util::monkey_patch($target => $class->_other_objects(@_));
  Mojo::Util::monkey_patch($target => $class->_add_other_object(@_));
  Mojo::Util::monkey_patch($target => $class->_search_other_objects(@_));
}

sub _other_objects {
  my($class, $accessor, $other) = @_;
  my $search = "search_$accessor";

  return $accessor => sub {
    my($self, $cb) = @_;

    $self->$search->all(sub {
      my($collection, $err, $objs) = @_;
      $self->$cb($err, $objs);
    });

    $self;
  };
}

sub _add_other_object {
  my($class, $accessor, $other) = @_;
  my $reverse;

  # Ex: persons => person
  $accessor =~ s/s$//;

  return "add_$accessor" => sub {
    my($self, $obj, $cb) = @_;
    my $foreign = $class->_foreign_key($self);

    if(ref $obj eq 'HASH') {
      my $model = $class->_load_class($other)->model;
      $obj = $model->collection_class->new({ connection => $self->connection, model => $model })->create($obj);
    }

    Mojo::IOLoop->delay(
      sub {
        my($delay) = @_;
        $obj->set("/$foreign" => $self->id)->save($delay->begin);
        $self->save($delay->begin) unless $self->in_storage;
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
  my($class, $accessor, $other) = @_;

  return "search_$accessor" => sub {
    my($self, $query, $extra) = @_;
    my $model = $class->_load_class($other)->model;
    my $foreign = $class->_foreign_key($self);

    $model->collection_class->new(
      connection => $self->connection,
      model => $model,
      extra => $extra || {},
      query => {
        %{ $query || {} },
        $foreign => $self->id,
      },
    );
  };
}

=head1 SEE ALSO

L<Mojolicious>, L<Mango>, L<Mandel::Relationship>

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
