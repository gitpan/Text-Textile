use Test::Simple tests=>1;
use Text::Textile qw(textile);

sub debug { $ENV{DEBUG} && print STDERR @_ }

my $source = '"title":http://www.example.com';
my $dest = textile($source);
my $expected = '<p><a href="http://www.example.com">title</a></p>';

if ($dest ne $expected) {
    debug("source is '$source'\n");
    debug("dest is '$dest'\n");
    debug("expected is '$expected'\n");
}

ok($dest eq $expected);
