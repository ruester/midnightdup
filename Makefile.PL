use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'MidnightDup',
    AUTHOR       => q{Matthias Rüster <matthias.ruester@gmail.com>},
    VERSION_FROM => 'midnightdup.pl',
    ABSTRACT     => 'MidnightDup - Duplicate file finder',
    (
        $ExtUtils::MakeMaker::VERSION >= 6.3002
        ? ( 'LICENSE' => 'lgpl_3_0' )
        : ()
    ),
    PL_FILES => {},
    PREREQ_PM => {
        'Tk' => '804.035',
        'File::Temp' => '0.2304',
        'File::Basename' => '2.85',
        'Cwd' => '3.74',
        'Digest::MD5' => '2.55',
        'Digest::MD5::File' => '0.08',
        'Number::Bytes::Human' => '0.11'
    },
    EXE_FILES => [
        'midnightdup.pl'
    ],
    TEST_REQUIRES => {},
);
