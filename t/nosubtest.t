use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/\\]+$}{}; $dir_name ||= '.';
    unshift @INC, $dir_name . '/lib/', $dir_name . '/../lib/';
}
use warnings;
use PackedTest;

!!1;

use Test::X1;

test {
    my $c = shift;
    $c->done;
};

test {
    my $c = shift;
    $c->done;
} n => 0;

test {
    my $c = shift;
    test {
        #
    } $c;
    $c->done;
};

run_tests;

!!1;

use Test::More tests => 3;

my ($output, $err) = PackedTest->run;

is $output, q{1..0
};

like $err, qr{# \[1\]: No subtests run!}m;
like $err, qr{# \[3\]: No subtests run!}m;
# "# No tests run!"
