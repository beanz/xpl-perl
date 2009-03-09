#!#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use Test::More tests => 12;
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

my $code;
my $lines;

# The begin block is global of course but this is where it is really used.
BEGIN{
  *CORE::GLOBAL::exit = sub { $code = $_[0]; die "EXIT\n" };
  require Pod::Usage; import Pod::Usage;
}
{
  local @ARGV = ('--help', '--interface' => 'lo');
  $lines =
    test_output(sub {
                  eval { xPL::Dock->new(port => 0, name => 'dingus'); }
                }, \*STDOUT);
}
is_deeply([split /\n/, $lines], \@usage, 'help content');
is($code, 1, 'help exit code');
undef $code;
undef $lines;
{
  local @ARGV = ('--man', '--interface' => 'lo');
  $lines =
    test_output(sub {
                  eval { xPL::Dock->new(port => 0, name => 'dingus'); }
                }, \*STDOUT);
}
like((split /\n/, $lines)[0],
  qr{^12-DOCK\.T\(1\)\s+User Contributed Perl Documentation\s+12-DOCK\.T\(1\)},
     'man content');
is($code, 0, 'man exit code');

undef $code;
undef $lines;
unshift @usage, 'Unknown option: bad-option';
{
  local @ARGV = ('--bad-option', '--interface' => 'lo');
  $lines =
    test_output(sub {
                  eval { xPL::Dock->new(port => 0, name => 'dingus'); }
                }, \*STDERR);
}
is_deeply([split /\n/, $lines], \@usage, 'bad option content');
is($code, 2, 'bad option exit code');

undef $lines;
undef $code;
my $good;
my $getopts = [ 'bad-option+' => \$good ];
{
  local @ARGV = ('--bad-option', '--interface' => 'lo');
  $lines =
    test_output(sub {
                  eval { xPL::Dock->new(getopts => $getopts,
                                        port => 0, name => 'dingus'); }
                }, \*STDERR);
}
is($good, 1, 'bad option made good - value');
ok(!$code, 'bad option made good - code');

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

# sample POD

=head1 NAME

dock/xpl-test - xPL Dock Test

=head1 SYNOPSIS

  dock/xpl-test [flags] [options]
  where valid flags are:
    -h - show this help text
    -v - verbose mode
  and valid options are (default shown in brackets):
    -i if0 - the interface for xPL messages (first non-loopback or loopback)

=head1 DESCRIPTION

Test POD.

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
