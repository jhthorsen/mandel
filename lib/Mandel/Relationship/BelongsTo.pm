package Mandel::Relationship::BelongsTo;

=head1 NAME

Mandel::Relationship::BelongsTo - A document is owned by another mongodb document

=head1 DESCRIPTION

Example:

  MyModel::Cat
    ->description
    ->relationship(belongs_to => owner => 'MyModel::Person');

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
use Mango::BSON 'bson_dbref';

=head1 ATTRIBUTES

=head2 foreign_field

The name of the field in this class which hold the "_id" to the related doc.

=cut

has foreign_field => sub { shift->accessor };

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
      if(ref $obj eq 'HASH') {
        $obj = $related_model->new_collection($doc->connection)->create($obj);
      }

      Mojo::IOLoop->delay(
        sub {
          my($delay) = @_;
          $obj->save($delay->begin);
          $doc->data->{$foreign_field} = bson_dbref $related_model->name, $obj->id;
          $doc->save($delay->begin);
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
        ->search({ _id => $doc->data->{$foreign_field}{'$id'} })
        ->single(sub { $doc->$cb(@_[1, 2]) });
    }

    $doc;
  });

  return $self;
}

=head1 SEE ALSO

L<Mojolicious>, L<Mango>, L<Mandel::Relationship>

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
