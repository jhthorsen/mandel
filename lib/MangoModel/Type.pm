package MangoModel::Type;

use Mojo::Base 'Mojo::Base';
use Carp;

has _raw => sub { {} };

has autosave => 1;
has model    => sub { croak 'Must have a model object reference' };
has updated  => 0;

sub import {
  my $caller = caller;
  {
    no strict 'refs';
    *{"${caller}::field"} = \&_field;
    if ( @_ > 1 ) { # arg to import is collection name
      my $collection = pop;
      *{"${caller}::collection"} = sub { $collection };
    }
  }
  push @_, __PACKAGE__;
  goto &Mojo::Base::import;
}

sub initialize {}

sub _field {
  my $field = shift;
  my $caller = caller;
  no strict 'refs';
  *{"${caller}::$field"} = sub { shift->_field_accessor( $field => @_ ) };
}

sub _field_accessor {
  my $self = shift;
  my $key = shift;
  my $raw = $self->_raw;

  # raw setter
  if ( @_ ) {
    $self->updated(1);
    $raw->{$key} = shift;
    return $self;
  } 

  return $raw->{$key};
}

sub DESTROY {
  my $self = shift;
  $self->save if $self->autosave && $self->updated;
}

sub collection { die 'collection must be overloaded by subclass' }

sub _collection { 
  my $self = shift;
  $self->model->mango->db->collection($self->collection);
}

sub save {
  my $self = shift;
  $self->_collection->save($self->_raw);
  $self->updated(0);
}

1;

