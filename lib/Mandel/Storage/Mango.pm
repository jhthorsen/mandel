package Mandel::Storage::Mango;

=head1 NAME

Mandel::Storage::Mango - Mongodb storage backend for Mandel

=head1 SYNOPSIS

  use Mandel;
  my $connection = Mandel->connect("mongodb://localhost/my_db");

=head1 DESCRIPTION

This is a storage backend for L<Mandel> that interact with
L<MongoDB|http://www.mongodb.com> using L<Mango>.

=cut

use Mojo::Base 'Mandel::Storage';
use Mango;

has _backend_class => 'Mango';

=head2 collection

  $obj = $self->collection($name);

=cut

sub collection {
  my($self, $name) = @_;

  $self->{collection}{$name} ||= $self->_backend->db->collection($name);
}

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
