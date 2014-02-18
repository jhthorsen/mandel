package Mandel::Relationship::HasOne;

=head1 NAME

Mandel::Relationship::HasOne - A field relates to another mongodb document

=head1 DESCRIPTION

Using DSL from L<Mandel::Document>:

  package MyModel::Cat;
  use Mandel::Document;
  has_one owner => 'MyModel::Person';

Using object oriented interface:

  MyModel::Cat
    ->model
    ->relationship(has_one => owner => 'MyModel::Person');

Will add:

  $cat = MyModel::Cat->new->owner(\%args, $cb);
  $cat = MyModel::Cat->new->owner($person_obj, $cb);

  $person_obj = MyModel::Cat->new->owner(\%args);
  $person_obj = MyModel::Cat->new->owner($person_obj);

  $person = MyModel::Cat->new->owner;
  $self = MyModel::Cat->new->owner(sub { my($self, $err, $person) = @_; });

See also L<Mandel::Model/relationship>.

=cut

use Mojo::Base 'Mandel::Relationship';
use Mojo::Util;
use Mango::BSON 'bson_dbref';

=head1 METHODS

=head2 monkey_patch

Add methods to L<Mandel::Relationship/document_class>.

=cut

sub monkey_patch {
  my $self = shift;
  my $foreign_field = $self->foreign_field;

  Mojo::Util::monkey_patch($self->document_class, $self->accessor, sub {
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
    my $doc = shift;
    my $obj = shift;
    my $related_model = $self->_related_model;

    if($obj) { # set ===========================================================
      my $related_collection = $self->_related_model->new_collection($doc->connection);

      if(ref $obj eq 'HASH') {
        $obj = $related_collection->create($obj);
      }

      Mojo::IOLoop->delay(
        sub {
          my($delay) = @_;
          $related_collection->search({ sprintf('%s.$id', $foreign_field), $doc->id })->remove($delay->begin);
        },
        sub {
          my($delay, @err) = @_;
          $doc->save($delay->begin);
          $obj->data->{$foreign_field} = bson_dbref $related_model->name, $doc->id;
          $obj->save($delay->begin);
        },
        sub {
          my($delay, @err) = @_;
          $doc->$cb($err[-1], $obj);
        },
      );
    }
    else { # get =============================================================
      $related_model
        ->new_collection($doc->connection)
        ->search({ sprintf('%s.$id', $foreign_field), $doc->id })
        ->single(sub { $doc->$cb(@_[1, 2]) });
    }

    return $doc;
  });

  return $self;
}

=head1 SEE ALSO

L<Mojolicious>, L<Mango>, L<Mandel::Relationship>

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
