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
my $cv2 = AE::cv;
$cv2->send(560);

test {
    my $c = shift;
    is $c->received_data, 12345;
    done $c;
} n => 1, wait => $cv;

test {
    my $c = shift;
    is $c->received_data, 12345;
    is $c->received_data, 12345;
    done $c;
} n => 2, wait => $cv;

test {
    my $c = shift;
    is $c->received_data, undef;
    done $c;
} n => 1, name => 'not waiting';

test {
    my $c = shift;
    is $c->received_data, 560;
    done $c;
} n => 1, wait => $cv2;

test {
    my $c = shift;
    is $c->received_data, 560;
    done $c;
} n => 1, wait => $cv2;

my $w = AE::timer 0.1, 0, sub {
    note "before cv->send";
    $cv->send(12345);
    note "after cv->send";
};

test {
    my $c = shift;
    is $c->received_data, undef;
    done $c;
} n => 1, name => 'not waiting 2';

run_tests;

!!1;

use Test::More tests => 1;

my ($output, $err) = PackedTest->run;

is $output, q{1..7
ok 1 - not waiting (3).1
ok 2 - (4).1
ok 3 - (5).1
ok 4 - not waiting 2 (6).1
# before cv->send
ok 5 - (2).1
ok 6 - (2).2
ok 7 - (1).1
# after cv->send
};
