use warnings;
use strict;
use Test::More tests=>2;
use Text::Textile qw(textile);

my $source = "* list1\n* list2\n* list3\n";
my $dest = textile($source);
my $expected = "\n<ul>\n<li>list1</li>\n<li>list2</li>\n<li>list3</li>\n</ul>";

is($dest, $expected);

$source = "# list1\n# list2\n# list3\n";
$dest = textile($source);
$expected = "\n<ol>\n<li>list1</li>\n<li>list2</li>\n<li>list3</li>\n</ol>";

is($dest, $expected);
