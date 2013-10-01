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
  my $sub_name = $class->_sub_name($field);

  return $sub_name => sub {
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
    my $self = shift;
    my $obj = shift;
    my $other_collection = $class->_load_class($other)->model->new_collection($self->connection);

    if($obj) { # set ===========================================================
      if(ref $obj eq 'HASH') {
        $obj = $other_collection->create($obj);
      }

      Mojo::IOLoop->delay(
        sub {
          my($delay) = @_;
          my $old = $self->get($field);
          $obj->save($delay->begin);
          $other_collection->search({ _id => $old })->remove($delay->begin) if $old;
        },
        sub {
          my($delay, $err) = @_;
          return $self->$cb($err, $obj) if $err;
          $self->set($field => $obj->id)->save($delay->begin);
        },
        sub {
          my($delay, $err) = @_;
          $self->$cb($err, $obj);
        },
      );
    }
    else { # get =============================================================
      my $model = $class->_load_class($other)->model;
      $model->collection_class
        ->new({ connection => $self->connection, model => $model })
        ->search({ _id => $self->get($field) })
        ->single(sub {
          my($collection, $err, $obj) = @_;
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
