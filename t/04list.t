use Test::Simple tests=>2;
use Text::Textile qw(textile);

sub debug { $ENV{DEBUG} && print STDERR @_ }

my $source = "* list1\n* list2\n* list3\n";
my $dest = textile($source);
my $expected = "<ul><li>list1</li>\n<li>list2</li>\n<li>list3</li>\n</ul>";

debug("source is '$source'\n");
debug("dest is '$dest'\n");
debug("expected is '$expected'\n");

ok($dest eq $expected);

$source = "# list1\n# list2\n# list3\n";
$dest = textile($source);
$expected = "<ol><li>list1</li>\n<li>list2</li>\n<li>list3</li>\n</ol>";

debug("source is '$source'\n");
debug("dest is '$dest'\n");
debug("expected is '$expected'\n");

ok($dest eq $expected);
