package Mandel::Relationship::ListOf;

=head1 NAME

Mandel::Relationship::ListOf - A field points to many other MongoDB documents

=head1 DESCRIPTION

L<Mandel::Relationship::ListOf> is a class used to describe the relationship
where one document has a list of DBRefs that point to other documents.
The connection between the documents is described in the database using
L<DBRef|http://docs.mongodb.org/manual/reference/database-references/>.

This relationship is EXPERIMENTAL. Let me of you are using it or don't like it.

=head1 DATABASE STRUCTURE

A "person" that has I<list of> "cats" will look like this in the database:

  mongodb> db.persons.find();
  {
    "_id" : ObjectId("5353ab13800fac3a0a8d5049"),
    "kittens" : [
      DBRef("cats", ObjectId("5353ab13c5483e16a1010000")),
      DBRef("cats", ObjectId("5353ab13c5483e16a1020000"))
    ]
  }

  mongodb> db.cats.find();
  { "_id" : ObjectId("5353ab13c5483e16a1010000") }
  { "_id" : ObjectId("5353ab13c5483e16a1020000") }

=head1 SYNOPSIS

=head2 Using DSL

  package MyModel::Person;
  use Mandel::Document;
  list_of cats => 'MyModel::Cat';

=head2 Using object oriented interface

  MyModel::Person->model->relationship(
    "list_of",
    "cats",
    "MyModel::Cat",
  );

See also L<Mandel::Model/relationship>.

=head2 Methods generated

  # non-blocking
  $person = MyModel::Person->new->push_cats($bson_oid, $pos, sub {
              my($person, $err, $cat_obj) = @_;
              # Note! This $cat_obj has only "id()" set
              # ...
            });

Add the C<$bson_oid> to the "cats" list in C<$person>.

  $person = MyModel::Person->new->push_cats(\%constructor_args, $pos, sub {
              my($person, $err, $cat_obj) = @_;
              # ...
            });

Pushing a new cat with C<%constructor_args> will also insert a new cat object
into the database.

  $person = MyModel::Person->new->push_cats($cat_obj, $pos, sub {
              my($person, $err, $cat_obj) = @_;
              # ...
            });

C<$pos> is optional. When omitted, C<push_cats()> will add the new element
to the end of list. See
L<http://docs.mongodb.org/manual/reference/operator/update/position/#up._S_position>
for details.

  $person = MyModel::Cat->new->remove_cats($bson_oid, sub {
              my($self, $err) = @_;
              # Note! This $cat_obj has only "id()" set
            });

  $person = MyModel::Cat->new->remove_cats($cat_obj, sub {
              my($self, $err) = @_;
              # ...
            });

Calling C<remove_cats()> will only remove the link, and not the related
object.

  $person = MyModel::Cat->new->cats(sub {
              my($self, $err, $array_of_cats) = @_;
              # ...
            });

Retrieve all the related cat objects.

  # blocking
  $cat_obj = MyModel::Person->new->push_cats($bson_oid);
  $cat_obj = MyModel::Person->new->push_cats(\%args);
  $cat_obj = MyModel::Person->new->push_cats($cat_obj);
  $person = MyModel::Person->new->remove_cats($bson_oid);
  $person = MyModel::Person->new->remove_cats($cat_obj);
  $array_of_cats = MyModel::Person->new->cats;

  $cat_collection = MyModel::Person->new->search_cats;

Note! C<search()> does not guaranty the order of the results, like C<cats()>
does.

=cut

use Mojo::Base 'Mandel::Relationship';
use Mojo::Util;
use Mango::BSON 'bson_dbref';

=head1 ATTRIBUTES

L<Mandel::Relationship::ListOf> inherits all attributes from
L<Mandel::Relationship> and implements the following new ones.

=head2 push_method_name

The name of the method used to add another document to the relationship.

=head2 remove_method_name

The name of the method used to remove an item from the list.

=head2 search_method_name

The name of the method used to search related documents.

=cut

has push_method_name => sub { sprintf 'push_%s', shift->accessor };
has remove_method_name => sub { sprintf 'remove_%s', shift->accessor };
has search_method_name => sub { sprintf 'search_%s', shift->accessor };

=head1 METHODS

L<Mandel::Relationship::ListOf> inherits all methods from
L<Mandel::Relationship> and implements the following new ones.

=head2 monkey_patch

Add methods to L<Mandel::Relationship/document_class>.

=cut

sub monkey_patch {
  shift
    ->_monkey_patch_all_method
    ->_monkey_patch_push_method
    ->_monkey_patch_remove_method
    ->_monkey_patch_search_method;
}

sub _monkey_patch_all_method {
  my $self = shift;
  my $accessor = $self->accessor;
  my $search = $self->search_method_name;

  Mojo::Util::monkey_patch($self->document_class, $self->accessor, sub {
    my($doc, $cb) = @_;
    my $cached = $doc->_cache($accessor);

    # Blocking
    unless ($cb) {
      return @$cached if $cached;
      my $objs = $doc->$search->all;
      my %lookup = map { $_->id, $_ } @$objs;
      my @objs = map { $lookup{$_->{'$id'}} } @{ $doc->data->{$accessor} || [] };
      $doc->_cache($accessor => \@objs);
      return @objs;
    }

    # Non-blocking
    $doc->$search->all(sub {
      my($collection, $err, $objs) = @_;
      my %lookup = map { $_->id, $_ } @$objs;
      my @objs = map { $lookup{$_->{'$id'}} } @{ $doc->data->{$accessor} || [] };

      $doc->_cache($accessor => \@objs);
      $doc->$cb($err, \@objs);
    });

    return $doc;
  });

  return $self;
}

sub _monkey_patch_push_method {
  my $self = shift;
  my $accessor = $self->accessor;

  Mojo::Util::monkey_patch($self->document_class, $self->push_method_name, sub {
    my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
    my($doc, $obj, $pos) = @_;
    my $cached = $doc->_cache($accessor);
    my($dbref, $list, @update);

    if(ref $obj eq 'HASH') {
      $obj = $self->_related_model->new_collection($doc->connection)->create($obj);
    }
    elsif(UNIVERSAL::isa($obj, 'Mango::BSON::ObjectID')) {
      $obj = $self->_related_model->new_collection($doc->connection)->create({ id => $obj });
      $obj->_mark_stored_clean; # prevent save() from actually doing something below
    }

    $dbref = bson_dbref $obj->model->collection_name, $obj->id;
    $list = $doc->data->{$accessor} ||= [];

    @update = (
      $doc->data,
      {
        '$push' => {
          $accessor => {
            '$each' => [ $dbref ],
            defined $pos ? ('$position' => $pos) : (),
          },
        },
      },
      {
        upsert => 1,
      },
    );

    # Blocking
    unless ($cb) {
      $obj->save;
      $doc->_storage_collection->update(@update);
      $doc->in_storage(1);

      if(defined $pos and $pos < @$list) {
        splice @$list, $pos, 0, $dbref;
      }
      else {
        push @$list, $dbref;
      }

      push @$cached, $obj if ref $cached eq 'ARRAY';
      return $obj;
    }

    # Non-blocking
    Mojo::IOLoop->delay(
      sub {
        my($delay) = @_;
        $obj->save($delay->begin);
        $doc->_storage_collection->update(@update, $delay->begin);
      },
      sub {
        my($delay, $o_err, $d_err, $updated) = @_;
        my $err = $o_err || $d_err;
        $err ||= 'Document was not stored. Unknown error' unless $updated and $updated->{n};

        unless($err) {
          $doc->in_storage(1);
          if(defined $pos and $pos < @$list) {
            splice @$list, $pos, 0, $dbref;
          }
          else {
            push @$list, $dbref;
          }
        }

        push @$cached, $obj if !$err and ref $cached eq 'ARRAY';
        $doc->$cb($err // '', $obj);
      },
    );

    return $doc;
  });

  return $self;
}

sub _monkey_patch_remove_method {
  my $self = shift;
  my $accessor = $self->accessor;

  Mojo::Util::monkey_patch($self->document_class, $self->remove_method_name, sub {
    my($doc, $obj, $cb) = @_;
    my $cached = $doc->_cache($accessor);
    my @update;

    unless (UNIVERSAL::isa($obj, 'Mandel::Document')) {
      $obj = $self->_related_model->new_collection($doc->connection)->create({ _id => $obj });
    }

    @update = (
      { _id => $doc->id },
      {
        '$pull' => {
          $accessor => bson_dbref($obj->model->collection_name, $obj->id),
        },
      },
    );

    # Blocking
    unless ($cb) {
      $doc->_storage_collection->update(@update);
      $doc->data->{$accessor} = [ grep { $_->{'$id'} ne $obj->id } @{ $doc->data->{$accessor} || [] } ];
      @$cached = grep { $_->{'$id'} ne $obj->id } @$cached if ref $cached eq 'ARRAY';
      return $doc;
    }

    # Non-blocking
    Mojo::IOLoop->delay(
      sub {
        my($delay) = @_;
        $doc->_storage_collection->update(@update, $delay->begin);
      },
      sub {
        my($delay, $err, $updated) = @_;
        $doc->data->{$accessor} = [ grep { $_->{'$id'} ne $obj->id } @{ $doc->data->{$accessor} || [] } ] unless $err;
        @$cached = grep { $_->{'$id'} ne $obj->id } @$cached if !$err and ref $cached eq 'ARRAY';
        $doc->$cb($err);
      },
    );

    return $obj;
  });

  return $self;
}

sub _monkey_patch_search_method {
  my $self = shift;
  my $accessor = $self->accessor;

  Mojo::Util::monkey_patch($self->document_class, $self->search_method_name, sub {
    my($doc, $query, $extra) = @_;
    my $related_model = $self->_related_model;

    return $related_model->new_collection(
      $doc->connection,
      extra => $extra || {},
      query => {
        %{ $query || {} },
        _id => {
          '$in' => [ map { $_->{'$id'} } @{ $doc->data->{$accessor} || [] } ],
        },
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
