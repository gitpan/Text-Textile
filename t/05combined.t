use Test::Simple tests=>1;
use Text::Textile qw(textile);

sub debug { $ENV{DEBUG} && print STDERR @_ }

my $source = <<SOURCE;
start paragraph

another paragraph

* list of things with "urls":http://www.jerakeen.org in
* more things in the list

a http://bare.url.here. and an email\@address.com

SOURCE

my $dest = textile($source)."\n";

my $expected = <<EXPECTED;
<p>start paragraph</p>

<p>another paragraph</p>


<ul>
<li>list of things with <a href="http://www.jerakeen.org">urls</a> in</li>
<li>more things in the list</li>
</ul>

<p>a http://bare.url.here. and an email\@address.com</p>
EXPECTED

if ($dest ne $expected) {
    debug("dest\n====\n$dest\n=======\n");
    debug("expected\n========\n$expected\n=======\n");
}

ok($dest eq $expected);

