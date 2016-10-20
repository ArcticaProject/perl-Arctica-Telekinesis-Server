use strict;
use ExtUtils::MakeMaker;

WriteMakefile (
  AUTHOR        => 'Arctica Project Developers',
  ABSTRACT      => "Arctica Telekinesis Server",
  NAME          => 'Arctica::Telekinesis::Server',
  (eval { ExtUtils::MakeMaker->VERSION(6.21) } ? (LICENSE => 'perl') : ()),
  PREREQ_PM     => {
    'Test::More' => '0.47',
  },
  VERSION_FROM  => 'lib/Arctica/Telekinesis/Server/Version.pm',
  clean               => { FILES => '' },
);
