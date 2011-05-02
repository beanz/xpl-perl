#!#!/usr/bin/perl -w
#
# Copyright (C) 2009, 2010 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use t::Helpers qw/test_warn test_error test_output/;
use t::Dock qw/check_sent_message/;
$|=1;
BEGIN {
  require Test::More;

  eval { require Net::Bluetooth; };
  if ($@) {
    import Test::More skip_all => 'No Net::Bluetooth perl module';
  }
  import Test::More tests => 10;
}

use_ok('xPL::Dock','Bluetooth');

my %devices = map { uc $_ => 1 } qw/00:1A:75:DE:DE:DE 00:1A:75:ED:ED:ED/;
{
  no warnings;
  no strict;
  *xPL::Dock::Bluetooth::sdp_search =
    sub { exists $devices{$_[0]} };
}

$ENV{XPL_HOSTNAME} = 'mytestid';
my $xpl;

my $count = 0;
{
  local $0 = 'dingus';
  local @ARGV = ('--verbose',
                 '--bluetooth-verbose', '--bluetooth-verbose',
                 '--interface', 'lo',
                 '--define', 'hubless=1', '00:1a:75:de:de:de');
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::Bluetooth', 'plugin has correct type');
my $output = test_output(sub { $xpl->dispatch_timer('poll-bluetooth') },
                         \*STDOUT);
is($output, "bt.00:1A:75:DE:DE:DE/input/high\n", 'is found output');
check_sent_message('is found message' => q!xpl-trig
{
hop=1
source=bnz-dingus.mytestid
target=*
}
sensor.basic
{
device=bt.00:1A:75:DE:DE:DE
type=input
current=high
}
!);

$output = test_output(sub { $xpl->dispatch_timer('poll-bluetooth') },
                         \*STDOUT);
is($output, '', 'is still found, no output');
check_sent_message('is still found message' => q!xpl-stat
{
hop=1
source=bnz-dingus.mytestid
target=*
}
sensor.basic
{
device=bt.00:1A:75:DE:DE:DE
type=input
current=high
}
!);

delete $devices{'00:1A:75:DE:DE:DE'};
$plugin->{_verbose} = 0;
$xpl->{_verbose} = 0;

$output = test_output(sub { $xpl->dispatch_timer('poll-bluetooth') },
                         \*STDOUT);
is($output, '', 'not found output - not verbose');
check_sent_message('not found message' => q!xpl-trig
{
hop=1
source=bnz-dingus.mytestid
target=*
}
sensor.basic
{
device=bt.00:1A:75:DE:DE:DE
type=input
current=low
}
!);
