#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 19;
use Time::HiRes;
use Cwd;
use t::Helpers qw/test_warn test_error test_output wait_for_variable/;
use lib 't/lib';
$|=1;

$ENV{XPL_PLUGIN_TO_WRAP} = 'xPL::Dock::HDDTemp';
use_ok('xPL::Dock','Wrap');

my @msg;
sub xPL::Dock::send_aux {
  my $self = shift;
  my $sin = shift;
  push @msg, [@_];
  my $msg;
  if (scalar @_ == 1) {
    $msg = shift;
  } else {
    eval {
      my %p = @_;
      $p{head}->{source} = $self->id if ($self->can('id') &&
                                         !exists $p{head}->{source});
      $msg = xPL::Message->new(%p);
      # don't think this can happen: return undef unless ($msg);
    };
    $self->argh("message error: $@") if ($@);
  }
  $msg;
}

$ENV{XPL_HOSTNAME} = 'mytestid';
my $device = IO::Socket::INET->new(Listen => 5, LocalAddr => '127.0.0.1:0');
ok($device, 'creating fake tcp hddtemp client');
my $sel = IO::Select->new($device);
my $port = $device->sockport();
my $xpl;

{
  local $0 = 'dingus';
  local @ARGV = ('-v',
                 '--interface', 'lo',
                 '--define', 'hubless=1',
                 '--hddtemp-verbose',
                 '--hddtemp-server' => '127.0.0.1:'.$port);
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock hddtemp client');
my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::Wrap', 'plugin has correct type');

ok(!$sel->can_read(0.2), 'hddtemp device not ready to accept');

$xpl->main_loop(1);

ok($sel->can_read(0.2), 'hddtemp device ready to accept - 1');
my $client = $device->accept;
ok($client, 'client accepted - 1');
my $client_sel = IO::Select->new($client);

$client->print('|/dev/sda|ST3320620AS|40|C||/dev/sdb|ST3320620AS|39|C|');

wait_for_variable($xpl, \$plugin->{_read_count});

check_sent_msg({
                message_type => 'xpl-trig',
                schema => 'sensor.basic',
                body =>
                [
                 device => 'mytestid-sda',
                 type => 'temp',
                 current => '40',
                ],
               }, 'checking xPL message - sda trig');
check_sent_msg({
                message_type => 'xpl-trig',
                schema => 'sensor.basic',
                body =>
                [
                 device => 'mytestid-sdb',
                 type => 'temp',
                 current => '39',
                ],
               }, 'checking xPL message - sdb trig');

$client->close;

$xpl->dispatch_timer('hddtemp');

ok($sel->can_read(0.2), 'hddtemp device ready to accept - 2');
$client = $device->accept;
ok($client, 'client accepted - 2');
$client_sel = IO::Select->new($client);

$client->print('|/dev/sda|ST3320620AS|40|C||/dev/sdb|ST3320620AS|40|C|');

wait_for_variable($xpl, \$plugin->{_read_count});

check_sent_msg({
                message_type => 'xpl-stat',
                schema => 'sensor.basic',
                body =>
                [
                 device => 'mytestid-sda',
                 type => 'temp',
                 current => '40',
                ],
               }, 'checking xPL message - sda stat');
check_sent_msg({
                message_type => 'xpl-trig',
                schema => 'sensor.basic',
                body =>
                [
                 device => 'mytestid-sdb',
                 type => 'temp',
                 current => '40',
                ],
               }, 'checking xPL message - sdb trig 2');

$client->close;

$xpl->dispatch_timer('hddtemp');

ok($sel->can_read(0.2), 'hddtemp device ready to accept - 3');
$client = $device->accept;
ok($client, 'client accepted - 3');
$client_sel = IO::Select->new($client);

$client->print('|/dev/sda|ST3320620AS|40|C||/dev/sdb|ST3320620AS|SPL|C|');

wait_for_variable($xpl, \$plugin->{_read_count});

check_sent_msg({
                message_type => 'xpl-stat',
                schema => 'sensor.basic',
                body =>
                [
                 device => 'mytestid-sda',
                 type => 'temp',
                 current => '40',
                ],
               }, 'checking xPL message - sda stat 2');
check_sent_msg({}, 'checking xPL message - sdb SPL');

$client->close;

$device->close;

is(test_warn(sub { $xpl->dispatch_timer('hddtemp'); }),
   ("Failed to contact hddtemp daemon at 127.0.0.1:".$port.
    ": Connection refused\n"),
   'connection failed');

sub check_sent_msg {
  my ($expected, $desc) = @_;
  my $msg = shift @msg;
  while (ref $msg->[0]) {
    $msg = shift @msg; # skip hbeat.* message
  }
  my %m = @{$msg};
  is_deeply(\%m, $expected, $desc);
}
