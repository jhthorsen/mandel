use Mojo::Base -strict;
use Test::More;

my @warnings;
$SIG{__WARN__} = sub { $_[0] =~ /Too late to run CHECK/ or push @warnings, $_[0]; };

eval <<"CODE" or die $@;
package My::Model;
use Mojo::Base 'Mandel';
1;
CODE

is_deeply \@warnings, [], 'no warnings on use Mojo::Base Mandel';

$INC{'My/Model.pm'} = 'test123';
eval <<"CODE" or die $@;
package App;
use Mojo::Base 'Mojolicious';
use My::Model;
1;
CODE

is_deeply \@warnings, [], 'no warnings on use My::Model';

eval <<"CODE" or die $@;
package My::Model2;
use Mandel;
1;
CODE

like $warnings[0], qr{use Mandel; will be deprecated.}, 'use Mandel; will be deprecated';

done_testing;
