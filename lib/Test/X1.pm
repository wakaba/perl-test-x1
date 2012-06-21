package Test::X1;
use strict;
use warnings;
our $VERSION = '1.0';

sub define_functions ($) {
    my $CLASS = shift;
    no strict 'refs';
    push @{$CLASS . '::EXPORT'}, qw(test run_tests);
    eval sprintf q{
        package %s;
        use Exporter::Lite;

        sub get_manager () {
            $%s::manager ||= %s::Manager->new;
        }

        sub test (&;@) {
            if (defined $_[1] and UNIVERSAL::isa($_[1], 'Test::X1::Context')) {
                get_manager->execute_with_context(@_);
             } else {
                get_manager->define_test(@_);
             }
        }
        
        sub run_tests () {
            get_manager->run_tests;
        }

        1;
    }, $CLASS, $CLASS, $CLASS or die $@;
}

Test::X1::define_functions(__PACKAGE__);

package Test::X1::Manager;
use Carp qw(croak);
use Test::More ();
use Term::ANSIColor ();

sub new {
    return bless {
        tests => [],
        #test_started
        #test_context
    }, $_[0];
}

sub define_test {
    my $self = shift;

    croak "Can't define a test after |run_tests| (\$c argument is missing?)"
        if $self->{test_started};

    my ($code, %args) = @_;
    $args{id} = 1 + @{$self->{tests}};
    push @{$self->{tests}}, [$code, \%args];
}

sub execute_with_context {
    local $_[0]->{test_context} = $_[2];
    return $_[1]->();
}

sub run_tests {
    my $self = shift;
    $self->{test_started} = 1;
    
    my $test_count = 0;
    my $more_tests;
    for (@{$self->{tests}}) {
        if (defined $_->[1]->{n}) {
            $test_count += $_->[1]->{n};
        } else {
            $more_tests = 1;
        }
    }

    Test::More::plan(tests => $test_count) if $test_count and not $more_tests;

    no warnings 'redefine';
    require Test::Builder;
    my $original_ok = Test::Builder->can('ok');
    local *Test::Builder::ok = sub {
        my ($builder, $test, $name) = @_;
        local $Test::Builder::Level = $Test::Builder::Level + 1;

        if ($self->{test_context}) {
            $name = $self->{test_context}->next_subtest_name unless defined $name;
            $self->{test_context}->{done_tests}++;
        }
        
        my $result = $original_ok->($builder, $test, $name);

        if ($self->{test_context} and not $result) {
            $self->{test_context}->{failed_tests}++;
        }

        return $result;
    };

    my $skipped_tests = 0;

    require AnyEvent;
    my $cv = AnyEvent->condvar;

    $self->within_test_env(sub {
        $cv->begin(sub {
            $self->terminate_test_env;
            $cv->send;
        });

        my $context_args = $self->context_args;

        my $context_class = ref $self;
        $context_class =~ s/::Manager$/::Context/;
        for (@{$self->{tests}}) {
            my $test_name;
            my $context = $context_class->new(
                args => $_->[1],
                cv => $cv,
                cb => sub {
                    $skipped_tests += $_[0]->{skipped_tests} || 0;
                },
                %$context_args,
            );
            local $self->{test_context} = $context;
            $cv->begin;
            eval {
                $_->[0]->($context);
                1;
            } or do {
                $context->receive_exception($@);
            };
        }

        $cv->end;
    });

    $cv->recv;
    delete $self->{test_context};

    Test::More::done_testing()
            unless $test_count and not $more_tests;
    if ($skipped_tests) {
        $self->diag(undef, sprintf "Looks like you skipped %d test%s.",
                               $skipped_tests, $skipped_tests == 1 ? '' : 's');
    }
}

sub within_test_env {
    my ($self, $code) = @_;
    $code->();
}

sub context_args {
    return {};
}

sub terminate_test_env {
    #
}

sub diag {
    if (-t STDOUT) {
        Test::More->builder->diag(Term::ANSIColor::colored [$_[1]], $_[2]);
    } else {
        Test::More->builder->diag($_[2]);
    }
}

package Test::X1::Context;

sub new {
    my $class = shift;
    return bless {@_}, $class;
}

sub test_name {
    my $self = shift;
    return $self->{test_name} ||= do {
        my $name = '(' . $self->{args}->{id} . ')';
        if (defined $self->{args}->{name}) {
            if (ref $self->{args}->{name} eq 'ARRAY') {
                $name = (join '.', @{$self->{args}->{name}}) . ' ' . $name;
            } else {
                $name = $self->{args}->{name} . ' ' . $name;
            }
        }
        $name;
    };
}

sub next_subtest_name {
    my $self = shift;
    my $local_id = $self->{done_tests} || 0;
    $local_id++;
    return $self->test_name . '.' . $local_id;
}

sub diag {
    my ($self, undef, $msg) = @_;
    Test::More->builder->diag($self->test_name . ': ' . $msg);
}

sub receive_exception {
    my ($self, $err) = @_;
    Test::More::is($err, undef, $self->test_name . '.lives_ok');
}

sub cb {
    if (@_ > 1) {
        $_[0]->{cb} = $_[1];
    }
    return $_[0]->{cb};
}

sub done {
    my $self = shift;

    my $done_tests = $self->{done_tests} || 0;
    my $failed_tests = $self->{failed_tests} || 0;
    if ($failed_tests) {
        $self->diag(undef, sprintf "%d test%s failed",
                               $failed_tests, $failed_tests == 1 ? '' : 's');
    }
    if (defined $self->{args}->{n}) {
        if ($self->{args}->{n} != $done_tests) {
            if ($self->{args}->{n} > $done_tests) {
                Test::More->builder->skip for 1..($self->{args}->{n} - $done_tests);
                $self->{skipped_tests} += ($self->{args}->{n} - $done_tests);
            }
            $self->diag(undef, sprintf "Looks like you planned %d test%s but ran %d.",
                            $self->{args}->{n},
                            $self->{args}->{n} == 1 ? '': 's',
                            $done_tests);
        }
    } elsif ($done_tests == 0) {
        $self->diag(undef, 'No test');
    }

    $self->{done} = 1;
    $self->{cb}->($self) if $self->{cb};

    $self->{cv}->end;
}

sub DESTROY {
    my $self = shift;
    unless ($self->{done}) {
        die "Can't continue test anymore (an exception is thrown before the test?)\n" unless $self->{cv};

        $self->diag(undef, "\$c->done is not invoked (or |die|d within test?)");
        $self->done;
    }
}

1;
