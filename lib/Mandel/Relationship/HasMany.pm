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
use Mango::Collection;

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
  my $search = "search_$field";

  return $field => sub {
    my($self, $cb) = @_;

    $self->$search->all(sub {
      my($collection, $err, $objs) = @_;
      return $self->$cb($err) if $err;
      $self->$cb($err, $objs);
    });

    $self;
  };
}

sub _add_other_object {
  my($class, $field, $other) = @_;
  my $singular = $field;

  # Ex: persons => person
  $singular =~ s/s$//;

  return "add_$singular" => sub {
    my($self, $obj, $cb) = @_;

    if(ref $obj eq 'HASH') {
      $obj = $class->_load_class($other)->new(%$obj, model => $self->model);
    }

    $obj->_collection->save($obj->_raw, sub {
      my($collection, $err, $doc);
      $self->$cb($err, $obj) if $err;
      push @{ $self->{_raw}{$field} }, $obj->id;
      $self->$cb($err, $obj);
    });

    $self;
  };
}

sub _search_other_objects {
  my($class, $field, $other) = @_;

  return "search_$field" => sub {
    my($self) = @_;
    my $ids = $self->{_raw}{$field} || [];

    return Mandel::Collection->new(
      connection => $self->connection,
      model => $self->model,
      query => {
        _id => { '$all' => [ @$ids ] },
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
