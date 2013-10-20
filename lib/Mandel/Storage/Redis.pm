package Mandel::Storage::Redis;

=head1 NAME

Mandel::Storage::Redis - Redis storage backend for Mandel

=head1 SYNOPSIS

  use Mandel;
  my $connection = Mandel->connect("redis://localhost/my_db");

=head1 DESCRIPTION

This is a storage backend for L<Mandel> that interact with
L<Redis|http://redis.io> using L<Mojo::Redis>.

=cut

use Mojo::Base -base;

=head1 ATTRIBUTES

=head2 url

=cut

has url => 'redis://localhost:6379';

=head1 METHODS

=head2 yyy

=cut

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
