#!#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use Test::More tests => 13;
use t::Helpers qw/test_warn test_error test_output/;
$|=1;

use_ok('xPL::Dock');

is(test_error(sub { xPL::Dock->import('invalid') }),
   q{Failed loading plugin: Can't locate xPL/Dock/invalid.pm in @INC},
   'plugin eval error');

my @usage = split /\n/,
  q{Usage:
      dock/xpl-test [flags] [options]
      where valid flags are:
        -h - show this help text
        -v - verbose mode
      and valid options are (default shown in brackets):
        -i if0 - the interface for xPL messages (first non-loopback or loopback)

};

my $cmd = $^X.' -Iblib/lib '.($ENV{HARNESS_PERL_SWITCHES}||'').
              ' t/dock/xpl-test';
my $fh;

open $fh, $cmd.' --help 2>&1 |' or die $!;
my $lines = lines($fh);
is_deeply($lines, \@usage, 'help content');
ok(!close $fh, 'help exit close');
is($?, 256, 'help exit code');

open $fh, $cmd.' --man 2>&1 |' or die $!;
$lines = lines($fh);
like($lines->[0],
     qr{^XPL-TEST\(1\)\s+User Contributed Perl Documentation\s+XPL-TEST\(1\)},
     'man content');
ok(close $fh, 'man exit close');
is($?, 0, 'man exit code');

unshift @usage, 'Unknown option: bad-option';
open $fh, $cmd.' --bad-option 2>&1 |' or die $!;
$lines = lines($fh);
is_deeply($lines, \@usage, 'bad option content');
ok(!close $fh, 'bad option close');
is($?, 512, 'bad option exit code');

sub lines {
  my @l = ();
  while (<$fh>) {
    chomp;
    push @l, $_ if ($_ ne '');
  }
  return \@l;
}

use_ok('xPL::Dock', 'Plug');
my @plugins;
{
  local $0 = 'xpl-test';
  @plugins = xPL::Dock->new->plugins;
}
ok(!$plugins[0]->getopts, 'default getopts list');
