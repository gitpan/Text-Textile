use Test::Simple tests=>1;
use Text::Textile qw(textile);

sub debug { $ENV{DEBUG} && print STDERR @_ }

my $source = "paragraph1\n\nparagraph2\n\n";
my $dest = textile($source);
my $expected = "<p>paragraph1</p>\n\n<p>paragraph2</p>";

if ($dest ne $expected) {
    debug("source is '$source'\n");
    debug("dest is '$dest'\n");
    debug("expected is '$expected'\n");
}

ok($dest eq $expected);
