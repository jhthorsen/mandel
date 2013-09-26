package Mandel;

=head1 NAME

Mandel - Simplistic Model Layer for Mango

=head1 SYNOPSIS

  package MyModel;
  use Mojo::Base 'Mandel';

=head1 DESCRIPTION

L<Mandel> is a simplistic model layer using the L<Mango> module to interact
with a MongoDB backend. This class defines the overall model, including high
level interaction. Individual results, called Types inherit from
L<Mandel::Document>.

=head1 WARNING

This code is at BEST alpha quality and anything can and will change or break.
DO NOT USE IN PRODUCTION CODE!

=head1 TODO

I want to replicate L<DBIx::Class> to some extent:
L<DBIx::Class::FilterColumn>,
L<DBIx::Class::InflateColumn>,
L<DBIx::Class::Relationship> and friends,
L<DBIx::Class::ResultSet>,
L<DBIx::Class::ResultSource>,
L<DBIx::Class::Row> and
L<DBIx::Class::Schema>.

=cut

use Mojo::Base 'Mojo::Base';
use Mojo::Loader;
use Mojo::Util;
use Mandel::Collection;
use Mango;
use Carp;

our $VERSION = '0.01';
$VERSION = eval $VERSION;

my $LOADER = Mojo::Loader->new;

=head1 ATTRIBUTES

L<Mandel> inherits all attributes from L<Mojo::EventEmitter> and implements
the following new ones.

=head2 mango

An instance of L<Mango> which acts as the database connection. If not
provided, one will be lazily created using the L</uri> attribute.

=head2 namespaces

The namespaces which will be searched when looking for Types. By default, the
(sub)class name of this module.

=head2 uri

The uri used by L<Mango> to connect to the MongoDB server.

=cut

has mango => sub { Mango->new( shift->uri or croak 'Please provide a uri' ) };
has namespaces => sub { [ ref $_[0] ] };
has uri => 'mongodb://localhost/mangomodeltest';

=head1 METHODS

L<Mandel> inherits all methods from L<Mojo::Base> and implements the following
new ones.

=head2 initialize

Takes a list of document names. Calls the C<initialize> method of any document
names passed in or if no names are passed then for all found document classes.

=cut

sub initialize {
  my $self = shift;
  my @documents = @_ ? @_ : $self->all_document_names;

  for my $document ( @documents ) {
    my $class = $self->class_for($document);
    my $collection = $self->mango->db->collection($class->collection);
    $class->initialize($self, $collection);
  }
}

=head2 all_document_names

Returns a list of all the documents in the L</namespaces>.

=cut

sub all_document_names {
  my $self = shift;
  my @names;

  for my $ns (@{ $self->namespaces }) {
    for my $name (@{ $LOADER->search($ns) }) {
      $name =~ s/^${ns}:://;
      push @names, Mojo::Util::decamelize($name);
    }
  }

  @names;
}

=head2 class_for

Given a document name, find the related class name, ensure that it is loaded
(or else die) and return it.

=cut

sub class_for {
  my ($self, $name) = @_;

  if(my $class = $self->{loaded}{$name}) {
    return $class;
  }

  for my $ns (@{ $self->namespaces }) {
    my $class = $ns . '::' . Mojo::Util::camelize($name);
    my $e = $LOADER->load($class);
    die $e if ref $e;
    next if $e;
    return $self->{loaded}{$name} = $class
  }

  Carp::carp "Could not find class for $name";
}

=head2 collection

  $collection_obj = $self->collection($name);

=cut

sub collection {
  my($self, $name) = @_;
  my $document_class = $self->class_for($name);

  Mango::Collection->new(
    document_class => $document_class,
    model => $self,
  );
}

=head1 SEE ALSO

L<Mojolicious>, L<Mango>

=head1 SOURCE REPOSITORY

L<http://github.com/jhthorsen/mandel>

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

This project is a fork of L<MangoModel|http://github.com/jberger/MangoModel>,
created by Joel Berger, E<lt>joel.a.berger@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Jan Henning Thorsen

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
