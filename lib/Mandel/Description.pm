package Mandel::Description;

=head1 NAME

Mandel::Description - An object describing a document

=cut

use Mojo::Base -base;
use Mojo::Loader;
use Mojo::Util;

my $LOADER = Mojo::Loader->new;

=head1 ATTRIBUTES

=head2 collection

=head2 document_class

=cut

has collection => '';
has document_class => '';

=head1 METHODS

=head2 add_field

  $self = $self->add_field('name');
  $self = $self->add_field(['name1', 'name2']);

Used to add new field(s) to this document.

=cut

sub add_field {
  my($self, $fields) = @_;
  my $class = $self->document_class;

  # Compile fieldibutes
  for my $field (@{ref $fields eq 'ARRAY' ? $fields : [$fields]}) {
    my $code = "package $class;\nsub $field {\n my \$r = \$_[0]->_raw;";
    $code .= "if (\@_ == 1) {\n";
    $code .= "    \$_[0]->{updated}=1;";
    $code .= "    return \$r->{'$field'};";
    $code .= "\n  }\n  \$r->{'$field'} = \$_[1];\n";
    $code .= "  \$_[0];\n}";

    # We compile custom attribute code for speed
    no strict 'refs';
    warn "-- Attribute $field in $class\n$code\n\n" if $ENV{MOJO_BASE_DEBUG};
    Carp::croak "Mandel::Document error: $@" unless eval "$code;1";
  }

  $self;
}

=head2 add_relationship

  $self->add_relationship(has_many => $field_name => 'Other::Document::Class');

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

=cut

sub add_relationship {
  my $self = shift;
  my $method = sprintf "_add_%s_relationship", shift;

  $self->$method(@_);
  $self;
}

sub _add_has_many_relationship {
  my($self, $field, $other) = @_;
  my $class = $self->document_class;
  my $singular = $field;

  $singular =~ s/s$//;

  $self->add_field($field);

  Mojo::Util::monkey_patch($class, "add_$singular" => sub {
    my($self, $obj, $cb) = @_;

    if(ref $obj eq 'HASH') {
      $obj = $self->_load_class($other)->new(%$obj, model => $self->model);
    }

    if($cb) {
      $obj->save(sub {
        my($obj, $err) = @_;
        $self->$cb($err, $obj) if $err;
        push @{ $self->{_raw}{$field} }, $obj->id;
        $self->$cb($err, $obj);
      });
      return $self;
    }
    else {
      return unless $obj->save;
      push @{ $self->{_raw}{$field} }, $obj->id;
      return $obj;
    }
  });

  Mojo::Util::monkey_patch($class, "search_$field" => sub {
    my($self) = @_;
    my $ids = $self->{_raw}{$field} || [];

    Mango::Collection->new(
      document_class => $self->_load_class($other),
      model => $self->model,
      query => {
        _id => { '$all' => [ @$ids ] },
      },
    );
  });
}

sub _load_class {
  my $class = pop;
  my $e = $LOADER->load($class);
  die $e if ref $e;
  $class;
}

=head1 SEE ALSO

L<Mojolicious>, L<Mango>, L<Mandel>

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;