#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 7;
use Time::HiRes;
use t::Helpers qw/test_warn test_error test_output/;
$|=1;

use_ok('xPL::Dock','WOL');

my @msg;
sub xPL::Dock::send_aux {
  my $self = shift;
  my $sin = shift;
  push @msg, [@_];
}

$ENV{XPL_HOSTNAME} = 'mytestid';
my $xpl;

{
  local $0 = 'dingus';
  local @ARGV = ('-v',
                 '--interface', 'lo',
                 '--define', 'hubless=1',
                 '--wol-verbose',
                 '--wol-sudo-command', 't/bin/sudo');
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock wol client');

my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::WOL', 'plugin has correct type');

is(test_output(sub {
                 $xpl->dispatch_xpl_message(
                   xPL::Message->new(message_type => 'xpl-cmnd',
                                     head =>
                                     {
                                      source => 'acme-wol.test',
                                     },
                                     class=> 'wol.basic',
                                     body =>
                                     [
                                      device => 'sleepy',
                                      type => 'wake',
                                     ])) }, \*STDOUT),
   ("Waking device sleepy\n".
    "executed: t/bin/sudo /usr/sbin/etherwake sleepy\n"),
   'testing execution');

is(test_output(sub {
                 $xpl->dispatch_xpl_message(
                   xPL::Message->new(message_type => 'xpl-cmnd',
                                     head =>
                                     {
                                      source => 'acme-wol.test',
                                     },
                                     class=> 'wol.basic',
                                     body =>
                                     [
                                      device => 'sneezy',
                                      type => 'sleep',
                                     ])) }, \*STDOUT),
   '',
   'testing execution - invalid type');

is(test_output(sub {
                 $xpl->dispatch_xpl_message(
                   xPL::Message->new(message_type => 'xpl-cmnd',
                                     head =>
                                     {
                                      source => 'acme-wol.test',
                                     },
                                     class=> 'wol.basic',
                                     body =>
                                     [
                                      type => 'wake',
                                     ])) }, \*STDOUT),
   '',
   'testing execution - no device');
