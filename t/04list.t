use Test::Simple tests=>2;
use Text::Textile qw(textile);

sub debug { $ENV{DEBUG} && print STDERR @_ }

my $source = "* list1\n* list2\n* list3\n";
my $dest = textile($source);
my $expected = "\n<ul>\n<li>list1</li>\n<li>list2</li>\n<li>list3</li>\n</ul>";

if ($dest ne $expected) {
    debug("source is '$source'\n");
    debug("dest is '$dest'\n");
    debug("expected is '$expected'\n");
}

ok($dest eq $expected);

$source = "# list1\n# list2\n# list3\n";
$dest = textile($source);
$expected = "\n<ol>\n<li>list1</li>\n<li>list2</li>\n<li>list3</li>\n</ol>";

if ($dest ne $expected) {
    debug("source is '$source'\n");
    debug("dest is '$dest'\n");
    debug("expected is '$expected'\n");
}

ok($dest eq $expected);
