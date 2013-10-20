package Mandel::Storage::Redis::Collection;

=head1 NAME

Mandel::Storage::Redis::Collection - Mirror Mango::Collection

=cut

use Mojo::Base -base;
use constant DEBUG => $ENV{DEBUG} ? 1 : 0;

our $VERSION = '0.01';

=head1 ATTRIBUTES

=head1 name

=cut

has name => sub { die "Required in constructor" };

=head2 storage

=cut

has storage => sub { die "Required in constructor" };

=head1 METHODS

=head2 save

=cut

sub save {
  my($self, $doc, $cb) = @_;

  $self->_backend->hset($self->_key($doc), $doc, sub {
    my($self, $saved) = @_;
    return $self->$cb('', $doc) if $saved;
    return $self->$cb('Could not save', $doc);
  });
}

sub _key {
  my($self, $doc) = @_;
  sprintf '%s:%s', $self->name, $doc->{_id};
}

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
