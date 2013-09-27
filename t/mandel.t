use Mojo::Base -strict;
use Test::More;
use lib 't/lib';
use MyModel;

my $model = MyModel->new;

is_deeply $model->namespaces, ['MyModel'], 'got namespaces';
is_deeply [$model->all_document_names], ['menu'], 'got document names';
is $model->class_for('menu'), 'MyModel::Menu', 'got class_for Menu';

done_testing;
