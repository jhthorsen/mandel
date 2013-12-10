package Mandel::Storage::Redis::Collection;

=head1 NAME

Mandel::Storage::Redis::Collection - Mirror Mango::Collection

=cut

use Mojo::Base -base;
use Time::HiRes qw( time );
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

=head2 remove

=cut

sub remove {
  my($self, $where, $extra, $cb) = @_;
  my $prefix = $self->_prefix($where);
  my $redis = $self->storage->_backend;
  my $namespace = $self->name;
  my $delay;

  $delay = Mojo::IOLoop->delay(
    sub { # get keys in document and start transaction
      my($delay) = @_;
      $redis->smembers("$prefix:m:keys" => $delay->begin);
      $redis->multi($delay->begin);
    },
    sub { # add new keys to document and delete old data
      my($delay, $members, $txn_started, $deleted) = @_;

      $redis->del("$prefix:d:$_") for @$members;
      $redis->del("$prefix:m:keys", $delay->begin);
      $redis->zrem("$namespace:i:_id", $where->{_id}, $delay->begin);
      $redis->exec($delay->begin);
    },
  );

  if($cb) {
    $delay->on(finish => sub {
      my($delay, @op_status) = @_;
      $self->$cb('', {}) if $cb; # TODO: Add error detection
    });
  }
  else {
    $delay->wait;
  }

  $self;
}

=head2 save

  $self = $self->save(\%doc, $cb);

=cut

sub save {
  my($self, $doc, $cb) = @_;
  my $prefix = $self->_prefix($doc);
  my $redis = $self->storage->_backend;
  my $namespace = $self->name;
  my $delay;

  unless(%$doc) {
    return $self->$cb('');
  }

  $delay = Mojo::IOLoop->delay(
    sub { # get keys in document and start transaction
      my($delay) = @_;
      $redis->smembers("$prefix:m:keys" => $delay->begin);
      $redis->zscore("$namespace:i:_id", $doc->{_id}, $delay->begin);
      $redis->multi($delay->begin);
      $redis->del("$prefix:m:keys", $delay->begin);
    },
    sub { # add new keys to document and delete old data
      my($delay, $members, $exists, $txn_started, $deleted) = @_;

      $redis->del("$prefix:d:$_") for @$members;
      $redis->zadd("$namespace:i:_id", time, $doc->{_id}, $delay->begin) unless $exists;
      $redis->sadd("$prefix:m:keys" => keys(%$doc), $delay->begin);
    },
    sub { # save document data
      my($delay, @op_status) = @_;

      for my $k (keys %$doc) {
        if(ref $doc->{$k} eq 'ARRAY') {
          $redis->lpush("$prefix:d:$k" => @{ $doc->{$k} }, $delay->begin);
        }
        elsif(ref $doc->{$k} eq 'HASH') {
          $redis->hmset("$prefix:d:$k" => %{ $doc->{$k} }, $delay->begin);
        }
        else {
          $redis->set("$prefix:d:$k" => $doc->{$k}, $delay->begin);
        }
      }
    },
    sub { # commit
      my($delay, @op_status) = @_;
      $redis->exec($delay->begin);
    },
  );

  if($cb) {
    $delay->on(finish => sub {
      my($delay, @op_status) = @_;
      $self->$cb('', $doc) if $cb; # TODO: Add error detection
    });
  }
  else {
    $delay->wait;
  }

  $self;
}

=head2 update

  $self = $self->update(\%where, \%doc, \%extra, $cb);

TODO: Complex C<%where> working on index.

=cut

sub update {
  my $cb = ref $_[-1] eq 'CODE' ? pop : undef;
  my $self = shift;
  my $delay;

  if($_[1]->{'$set'}) {
    $delay = $self->_patch(@_);
  }
  else {
    die 'Not implemented';
  }

  if(!$delay) {
    $self->$cb('', {}) if $cb;
  }
  elsif($cb) {
    $delay->on(finish => sub {
      my($delay, @op_status) = @_;
      $self->$cb('', {}) if $cb; # TODO: Add error detection
    });
  }
  else {
    $delay->wait;
  }

  return $self;
}

sub _patch {
  my($self, $where, $doc, $extra) = @_;
  my $prefix = $self->_prefix($where);
  my $redis = $self->storage->_backend;
  my $namespace = $self->name;

  $doc = $doc->{'$set'};

  Mojo::IOLoop->delay(
    sub {
      my($delay) = @_;
      $redis->zscore("$namespace:i:_id", $where->{_id}, $delay->begin);
      $redis->multi($delay->begin);
      $redis->sadd("$prefix:m:keys", keys %$doc);
    },
    sub {
      my($delay, $exists, $txn_started, $added) = @_;

      for my $k (keys %$doc) {
        if(ref $doc->{$k} eq 'ARRAY') {
          $redis->del($k)->lpush("$prefix:d:$k" => @{ $doc->{$k} });
        }
        elsif(ref $doc->{$k} eq 'HASH') {
          $redis->del($k)->hmset("$prefix:d:$k" => %{ $doc->{$k} });
        }
        else {
          $redis->set("$prefix:d:$k" => $doc->{$k});
        }
      }

      $redis->zadd("$namespace:i:_id", time, $doc->{_id}) unless $exists;
      $redis->exec($delay->begin);
    },
  );
}

sub _prefix {
  sprintf '%s:%s', $_[0]->name, $_[1]->{_id};
}

=head1 COPYRIGHT

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
