use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/\\]+$}{}; $dir_name ||= '.';
    unshift @INC, $dir_name . '/lib/', $dir_name . '/../lib/';
}
use warnings;
use warnings FATAL => 'recursion';
use PackedTest;

!!1;

use Test::X1;
use Test::More;
use AnyEvent;

my @cv;
push @cv, AE::cv for 0..6;

for my $i (1..1000) {
    test {
        my $c = shift;
        ok 1;
        done $c;
    } n => 1;
}

run_tests;

!!1;

use Test::More tests => 2;

my ($output, $err) = PackedTest->run;

is $output, q{1..1000
} . join '', map { "ok $_ - [$_] - [1]\n" } 1..1000;

is $err, '';
