use ExtUtils::MakeMaker;
WriteMakefile(
  NAME => 'Mandel',
  ABSTRACT_FROM => 'lib/Mandel.pm',
  VERSION_FROM => 'lib/Mandel.pm',
  AUTHOR => 'Jan Henning Thorsen <jhthorsen@cpan.org>',
  LICENSE => 'perl',
  PREREQ_PM => {
    'Mango' => '0.12',
    'Mojolicious' => '3.40',
    'Type::Tiny' => '0.014',
  },
  BUILD_REQUIRES => {
    'Test::More' => '0.90',
  },
  META_MERGE => {
    resources => {
      license => 'http://dev.perl.org/licenses/',
      homepage => 'https://metacpan.org/release/Mandel',
      bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Mandel',
      repository => 'https://github.com/jhthorsen/mandel',
    },
  },
  test => {
    TESTS => 't/*.t',
  },
);
