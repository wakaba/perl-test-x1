use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/\\]+$}{}; $dir_name ||= '.';
    unshift @INC, $dir_name . '/lib/', $dir_name . '/../lib/';
}
use warnings;
use PackedTest;

!!1;

use Test::X1;

run_tests;

!!1;

use Test::More tests => 2;

my ($output, $err, $result) = PackedTest->run;

is $output, q{1..0
};

#is $err, q{# No tests run!
#};

isnt $result >> 8, 0, "exit code is error";
