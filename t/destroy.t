use Mojo::Base -strict;
use Test::More;

use lib 't/lib';
use MyModel;

my $seen = 0;
{
  my $model = MyModel->new;
  $model->on( destroy => sub { $seen++ } );
  ok ! $seen, 'DESTROY has not fired';
}

ok $seen, 'DESTROY has fired';

done_testing;

