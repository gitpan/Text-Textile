use Test::Simple tests=>1;

use Text::Textile qw(textile);

ok(textile("") eq "");
