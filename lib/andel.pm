package andel;

=head1 NAME

andel - Oneliner Mandel magic

=head1 SYNOPSIS

  perl -Mandel=MyModel -e'c("users", { name => "joe" })'
  perl -Mandel=MyModel -e'c("users")->count'

=cut

use Mojo::Base -strict;

my $mandel;

=head1 METHODS

=head2 import

See L</SYNOPSIS>.

=cut

sub import {
  my $class = shift;
  my $caller = caller;

  @_ or die "Usage: perl -Mandel,My::Model -e'...'";
  $class->_setup(@_);
  no strict 'refs';
  *{"$caller\::c"} = \&_c;
}

sub _setup {
  my($class, $model, $database) = @_;
  eval "use $model; 1" or die "use $model: $@";
  $database ||= 'test';
  $mandel = $model->connect("mongodb://localhost/$database");
}

sub _c {
  my $name = shift or die "Usage: c('collection_name')";
  my $collection = $mandel->collection($name);

  if(@_ and ref $_[0] eq 'HASH') {
    return $collection->create($_[0]);
  }

  return $collection;
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
