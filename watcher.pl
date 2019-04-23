#!/usr/bin/perl

use strict;
use warnings;
use autodie;
use Time::HiRes ();

my $conf = do $ARGV[0];

main();

sub main {
    while (1) {
        watch_log();
    }
}

# sleep at least 1 second but no more than 2 seconds.
sub nap {
    my $sec = 1 + rand 1;
    Time::HiRes::sleep($sec);
}

sub watch_log {
    my $fh;
    retry(\&open, $fh, '<', $conf->{in});
    seek $fh, 0, 2;                     # end of the file
	while ((stat $fh)[3] != 0) {        # number of (hard) links to the file
		while (my $line = <$fh>) {
			chomp $line;
			check($line);
		}
        nap();
		seek $fh, 0, 1;                 # current position (emulates 'tail -f')
	}
	close $fh;
}

sub retry {
    my $coderef = shift;
	for (my $i = 1; $i <= $conf->{max_try}; $i++) {
		eval {
            $coderef->(@_);
        };
		if ($@) {
			if ($i == $conf->{max_try}) {
                die $@
			}
            else {
                warn $@;
                nap();
            }
        }
        else {
            return;
        }
	}
}

sub check {
	my $line = shift;
	for my $pattern (@{$conf->{patterns}}) {
        my $tag = $pattern->{tag};
        my $re = $pattern->{re};
		if ($line =~ $re) {
			if ($tag ne '!') {
                write_log($tag, $line);
			}
			last;
		}
	}
}

sub write_log {
    my ( $tag, $line ) = @_;
    my $fh;
    retry(\&open, $fh, '>>', $conf->{out});
    print $fh "$line\n";
    close $fh;
}

# vim: set ts=4 sw=4 sts=4 et :
