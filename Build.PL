#!/usr/bin/perl
use strict;
use warnings;
use Module::Build;

my $build = Module::Build->new(
    module_name => 'Hash::StoredIterator',
    license     => 'perl',
    dist_author => 'Chad Granum <exodist7@gmail.com>',
    create_readme => 1,
    requires => {
        'perl' => '5.10.0',
    },
    build_requires => {
        'Fennec' => '1.012',
    },
);

$build->create_build_script;
