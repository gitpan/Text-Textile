#!/usr/bin/perl -Tw

use warnings;
use strict;

use Test::More tests=>1;
use Text::Textile qw(textile);

my $source = "paragraph1\n\nparagraph2\n\n";
my $dest = textile($source);
my $expected = "<p>paragraph1</p>\n\n<p>paragraph2</p>";

is($dest, $expected, 'Do we match?');
