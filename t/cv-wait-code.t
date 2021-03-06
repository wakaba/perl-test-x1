use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/\\]+$}{}; $dir_name ||= '.';
    unshift @INC, $dir_name . '/lib/', $dir_name . '/../lib/';
}
use warnings;
use PackedTest;

!!1;

use Test::X1;
use Test::More;
use AnyEvent;

my $cv = AE::cv;
my $i = 0;

test {
    my $c = shift;
    is $c->received_data, 12345;
    done $c;
} n => 1, wait => sub { $i++; $cv };

test {
    my $c = shift;
    is $c->received_data, 12345;
    is $c->received_data, 12345;
    done $c;
} n => 2, wait => sub { $i++; $cv };

test {
    my $c = shift;
    is $c->received_data, undef;
    done $c;
} n => 1, name => 'not waiting', wait => sub { $i++; undef };

my $w = AE::timer 0.1, 0, sub {
    note "before cv->send";
    $cv->send(12345);
    note "after cv->send";
};

test {
    my $c = shift;
    is $i, 3;
    done $c;
} n => 1, name => 'wait invocation';

run_tests;

!!1;

use Test::More tests => 1;

my ($output, $err) = PackedTest->run;

is $output, q{1..5
ok 1 - [3] not waiting - [1]
ok 2 - [4] wait invocation - [1]
# before cv->send
ok 3 - [2] - [1]
ok 4 - [2] - [2]
ok 5 - [1] - [1]
# after cv->send
};
