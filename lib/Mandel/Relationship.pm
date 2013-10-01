package Mandel::Relationship;

=head1 NAME

Mandel::Relationship - Base class for relationships

=head1 DESCRIPTION

=over 4

=item * L<Mandel::Relationship::HasMany>

=item * L<Mandel::Relationship::HasOne>

=back

=cut

use Mojo::Base -base;
use Mojo::Loader;

my $LOADER = Mojo::Loader->new;

sub _load_class {
  my $class = pop;
  my $e = $LOADER->load($class);
  die $e if ref $e;
  $class;
}

# /foo/1/bar => foo_1_bar
sub _sub_name {
  local $_ = $_[1];
  s!/!_!g;
  s!^_+!!;
  $_;
}

=head1 SEE ALSO

L<Mojolicious>, L<Mango>, L<Mandel>

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
