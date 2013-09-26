package Mandel::Description;

=head1 NAME

Mandel::Description - An object describing the a document

=cut

use Mojo::Base -base;

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

  $class;
}

=head1 SEE ALSO

L<Mojolicious>, L<Mango>

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;