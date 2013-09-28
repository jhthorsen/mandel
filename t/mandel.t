use Mojo::Base -strict;
use Test::More;
use lib 't/lib';
use MyModel;

{
  my $model = MyModel->new;

  is_deeply $model->namespaces, ['MyModel'], 'got namespaces';
  is_deeply [$model->all_document_names], ['menu'], 'got document names';
  is $model->class_for('menu'), 'MyModel::Menu', 'got class_for Menu';
}

{
  my $model = MyModel->new(model_class => 'Dummy::Namespace')->connect;
  my $clone = $model->connect;
  isnt $model->storage, $clone->storage, 'created clone, with fresh storage';
  is $model->model_class, $clone->model_class, 'but with same model_class';
}

done_testing;
