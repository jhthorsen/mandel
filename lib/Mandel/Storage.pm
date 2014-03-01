package Mandel::Storage;

=head1 NAME

Mandel::Storage - Base class for Mandel storage modules

=head1 VERSION

0.01

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use Mojo::Base -base;
our $AUTOLOAD;

has _backend => sub { shift->_backend_class->new };

=head2 AUTOLOAD

All other methods will be proxied to the backend object.

=cut

sub AUTOLOAD {
  my $self = shift;
  $AUTOLOAD =~ /::(\w+)$/;
  my $method = $1;
  $self->_backend->$method(@_);
}

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
