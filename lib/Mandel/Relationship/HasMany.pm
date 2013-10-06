package Mandel::Relationship::HasMany;

=head1 NAME

Mandel::Relationship::HasMany - A field relates to many other mongodb document

=head1 DESCRIPTION

Example:

  MyModel::Cat
    ->description
    ->relationship(has_many => owners => 'MyModel::Person');

Will add:

  $cat = MyModel::Cat->new->add_owners(\%args, $cb);
  $cat = MyModel::Cat->new->add_owners($person_obj, $cb);

  $person_obj = MyModel::Cat->new->add_owners(\%args);
  $person_obj = MyModel::Cat->new->add_owners($person_obj);

  $persons = MyModel::Cat->new->search_owners;

  $person_objs = MyModel::Cat->new->owners;
  $self = MyModel::Cat->new->owners(sub {
    my($self, $err, $person_objs) = @_;
  });

=cut

use Mojo::Base 'Mandel::Relationship';
use Mojo::Util;
use Mango::BSON 'bson_dbref';

=head1 ATTRIBUTES

=head2 add_method_name

The name of the method used to add another document to the .

=head2 search_method_name

The name of the method used to search related documents.

=cut

has add_method_name => sub { sprintf 'add_%s', shift->accessor };
has search_method_name => sub { sprintf 'search_%s', shift->accessor };

=head1 METHODS

=head2 monkey_patch

Add methods to L<Mandel::Relationship/document_class>.

=cut

sub monkey_patch {
  shift
    ->_monkey_patch_all_method
    ->_monkey_patch_add_method
    ->_monkey_patch_search_method;
}

sub _monkey_patch_all_method {
  my $self = shift;
  my $search = $self->search_method_name;

  Mojo::Util::monkey_patch($self->document_class, $self->accessor, sub {
    my($doc, $cb) = @_;

    $doc->$search->all(sub {
      my($collection, $err, $objs) = @_;
      $doc->$cb($err, $objs);
    });

    return $doc;
  });

  return $self;
}

sub _monkey_patch_add_method {
  my $self = shift;
  my $foreign_field = $self->foreign_field;

  Mojo::Util::monkey_patch($self->document_class, $self->add_method_name, sub {
    my($doc, $obj, $cb) = @_;
    my $related_model = $self->_related_model;

    if(ref $obj eq 'HASH') {
      $obj = $related_model->new_collection($doc->connection)->create($obj);
    }

    Mojo::IOLoop->delay(
      sub {
        my($delay) = @_;
        $obj->data->{$foreign_field} = bson_dbref $related_model->name, $doc->id;
        $obj->save($delay->begin);
        $doc->save($delay->begin);
      },
      sub {
        my($delay, @err) = @_;
        $doc->$cb($err[-1], $obj);
      },
    );

    return $doc;
  });

  return $self;
}

sub _monkey_patch_search_method {
  my $self = shift;
  my $foreign_field = $self->foreign_field;
  my $related_class = $self->related_class;

  Mojo::Util::monkey_patch($self->document_class, $self->search_method_name, sub {
    my($doc, $query, $extra) = @_;
    my $related_model = $self->_related_model;

    return $related_model->new_collection(
      $doc->connection,
      extra => $extra || {},
      query => {
        %{ $query || {} },
        sprintf('%s.$id', $foreign_field) => $doc->id,
      },
    );
  });

  return $self;
}

=head1 SEE ALSO

L<Mojolicious>, L<Mango>, L<Mandel::Relationship>

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
