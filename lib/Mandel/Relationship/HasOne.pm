package Mandel::Relationship::HasOne;

=head1 NAME

Mandel::Relationship::HasOne - A field relates to another mongodb document

=head1 DESCRIPTION

Example:

  MyModel::Cat
    ->description
    ->add_relationship(has_one => owners => 'MyModel::Person');

Will add:

  $cat = MyModel::Cat->new->owner(\%args, $cb);
  $cat = MyModel::Cat->new->owner($person_obj, $cb);

  $person_obj = MyModel::Cat->new->owner(\%args);
  $person_obj = MyModel::Cat->new->owner($person_obj);

  $person = MyModel::Cat->new->owner;
  $self = MyModel::Cat->new->owner(sub { my($self, $err, $person) = @_; });

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

  Mojo::Util::monkey_patch($target => $class->_other_object(@_));
}

sub _other_object {
  my($class, $field, $other) = @_;
  my $sub_name = $field;

  # /foo/1/bar => foo_1_bar
  $sub_name =~ s!/!_!;
  $sub_name =~ s!^_+!!;

  return $sub_name => sub {
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
    my $self = shift;
    my $obj = shift;

    if($obj) { # set ===========================================================
      if(ref $obj eq 'HASH') {
        $obj = $class->_load_class($other)->new(%$obj, model => $self->model, connection => $self->connection);
      }

      $obj->save(sub {
        my($obj, $err, $doc) = @_;
        $self->$cb($err, $obj) if $err;
        $self->set($field => $obj->id);
        $self->{_raw}{$field} = $obj->id; # TODO: Should this also be saved to database?
        $self->{$sub_name} = $obj;
        $self->$cb($err, $obj);
      });
    }
    else { # get =============================================================
      my $collection = $self->connection->_collection($other->description->collection);
      $collection->find_one({ _id => $self->get($field) }, sub {
        my($collection, $err, $doc);
        $self->$cb($err, $obj) if $err;
        $obj = $class->_load_class($other)->new(%$doc, model => $self->model, connection => $self->connection);
        $self->{$sub_name} = $obj;
        $self->$cb($err, $obj);
      });
    }

    $self;
  };
}

=head1 SEE ALSO

L<Mojolicious>, L<Mango>, L<Mandel::Relationship>

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
