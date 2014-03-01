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

use Mojo::Base 'Mandel::Storage';
use Mojo::Redis;
use Mandel::Storage::Redis::Collection;
# use Mandel::Storage::Redis::Cursor;

has _backend_class => 'Mojo::Redis';

=head1 METHODS

=head2 new

  $self = $class->new($url);

=cut

sub new {
  my $self = shift->SUPER::new;
  my $url = shift;

  $self->_backend($self->_backend_class->new(server => $url)) if $url;
  $self;
}

=head2 collection

  $obj = $self->collection($name);

=cut

sub collection {
  my($self, $name) = @_;

  $self->{collection}{$name} ||= Mandel::Storage::Redis::Collection->new(name => $name, storage => $self);
}

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
