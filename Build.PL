#!/usr/bin/perl
use warnings;
use strict;

use Module::Build;

Module::Build->new(
    module_name => 'Text::Textile',
    requires => {
        'perl'        => '5.6.0',
    },
    create_makefile_pl => 'traditional',
)->create_build_script;

