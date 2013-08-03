use strict;
use warnings;

use Module::Build;

my $builder = Module::Build->new(
  module_name => 'MangoModel',
  dist_author => 'Joel A. Berger <joel.a.berger@gmail.com>',
  license  => 'perl',
  configure_requires => {
    'Module::Build' => 0.36,
  },
  requires => {
    'perl'  => '5.10.1',
    'Mango' => 0,
  },
  meta_merge => {
    resources  => {
      repository => "http://github.com/jberger/MangoModel",
      bugtracker => "http://github.com/jberger/MangoModel/issues",
    },
    no_index => {
      file      => [ 'README.pod' ],
      directory => [ 't' ],
    },
  },
);

$builder->create_build_script;
