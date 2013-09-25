use Mojo::Base -strict;
use Test::More;
use MangoModel::Type;

my $type = MangoModel::Type->new;

isa_ok $type->id, 'Mango::BSON::ObjectID';

$type->id('507f1f77bcf86cd799439011');
isa_ok $type->id, 'Mango::BSON::ObjectID';
is $type->id->to_string, '507f1f77bcf86cd799439011', 'set from string';

$type->id(Mango::BSON::ObjectID->new);
ok $type->id->to_string, 'set from object';
isnt $type->id->to_string, '507f1f77bcf86cd799439011', 'changed string';
$type->autosave(0);

$type = MangoModel::Type->new(id => '507f1f77bcf86cd799439011');
is $type->id->to_string, '507f1f77bcf86cd799439011', 'set in constructor';
$type->autosave(0);

done_testing;
