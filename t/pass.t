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

test {
    my $c = shift;
    my $timer; $timer = AnyEvent->timer(
        after => 0.2,
        cb => sub {
            test {
                undef $timer;
                ok 1;
                $c->done;
            } $c;
        },
    );
} n => 1, name => ['ae', 'timer'];

test {
    my $c = shift;
    ok 1;
    is 120, 120;
    $c->done;
} n => 2, name => ['sync-only'];

run_tests;

!!1;

use Test::More tests => 5;

my ($output, $err) = PackedTest->run;

like $output, qr/^1\.\.3$/m;

like $output, qr/^ok \d+ - \[1\] ae\.timer - \[1\]$/m;

like $output, qr/^ok \d+ - \[2\] sync-only - \[1\]$/m;
like $output, qr/^ok \d+ - \[2\] sync-only - \[2\]$/m;

unlike $output, qr/^not ok/m;
