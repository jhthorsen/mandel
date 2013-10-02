package Mandel::Relationship::BelongsTo;

=head1 NAME

Mandel::Relationship::BelongsTo - A document is owned by another mongodb document

=head1 DESCRIPTION

Example:

  MyModel::Cat
    ->description
    ->add_relationship(belongs_to => owner => 'MyModel::Person');

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

  $clsas->create($target => $accessor => 'Other::Document::Class');

=cut

sub create {
  my $class = shift;
  my $target = shift;

  Mojo::Util::monkey_patch($target => $class->_other_object(@_));
}

sub _other_object {
  my($class, $accessor, $other) = @_;

  return $accessor => sub {
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
    my $self = shift;
    my $obj = shift;
    my $other_collection = $class->_load_class($other)->model->new_collection($self->connection);
    my $foreign = $class->_foreign_key($other);

    if($obj) { # set ===========================================================
      if(ref $obj eq 'HASH') {
        $obj = $other_collection->create($obj);
      }

      Mojo::IOLoop->delay(
        sub {
          my($delay) = @_;
          $obj->save($delay->begin) unless $obj->in_storage;
          $self->set("/$foreign", $obj->id)->save($delay->begin);
        },
        sub {
          my($delay, @err) = @_;
          $self->$cb($err[-1], $obj);
        },
      );
    }
    else { # get =============================================================
      my $model = $class->_load_class($other)->model;
      $model->collection_class
        ->new({ connection => $self->connection, model => $model })
        ->search({ $foreign => $self->id })
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
