#!#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 28;
use t::Helpers qw/test_warn test_error test_output/;
$|=1;

use_ok('xPL::Dock','RFXComRX');
use_ok('xPL::BinaryMessage');

my @msg;
sub xPL::Dock::send_aux {
  my $self = shift;
  my $sin = shift;
  push @msg, [@_];
}

$ENV{XPL_HOSTNAME} = 'mytestid';
my $device = IO::Socket::INET->new(Listen => 5, LocalAddr => '127.0.0.1:0');
ok($device, 'creating fake tcp serial client');
my $sel = IO::Select->new($device);
my $port = $device->sockport();
my $xpl;

{
  local $0 = 'dingus';
  local @ARGV = ('-v',
                 '--interface', 'lo',
                 '--define', 'hubless=1',
                 '--rfxcom-rx', '127.0.0.1:'.$port);
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
ok($sel->can_read, 'device ready to accept');
my $client = $device->accept;
ok($client, 'client accepted');
my $client_sel = IO::Select->new($client);

my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::RFXComRX', 'plugin has correct type');

foreach my $r (['F020' => '4d26'], ['F02A' => '41'], ['F041' => '41']) {
  my ($recv,$send) = @$r;
  ok($client_sel->can_read, 'device receive a message - '.$recv);
  my $buf = '';
  is((sysread $client, $buf, 64), length($recv)/2,
     'read is correct size - '.$recv);
  my $m = xPL::BinaryMessage->new(raw => $buf);
  is($m, lc $recv, 'content is correct - '.$recv);

  print $client pack 'H*', $send;

  if ($send eq "4d26") {
    is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
       "Not a variable length message: 4d26\n", 'read response - '.$send);
  } else {
    $xpl->main_loop(1);
    is((unpack 'H*', $plugin->{_buffer}), $send, 'read response - '.$send);
    $plugin->{_buffer} = '';
  }
#  check_sent_msg('dmx.confirm', '0x'.$color, '1');
}

print $client pack 'H*', '20649b08f7';
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "xpl-trig/x10.basic: bnz-dingus.mytestid -> * - on a11\n",
   'read response - a11/on');
check_sent_msg(q!xpl-trig
{
hop=1
source=bnz-dingus.mytestid
target=*
}
x10.basic
{
command=on
device=a11
}
!);
print $client pack 'H*', '20649b08f7';
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   '', # duplicate
   'read response - a11/on');
check_sent_msg(undef);

$xpl->verbose(0);
print $client pack 'H*', '20649b28d7';
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "xpl-trig/x10.basic: bnz-dingus.mytestid -> * - off a11\n",
   'read response - a11/off');
check_sent_msg(q!xpl-trig
{
hop=1
source=bnz-dingus.mytestid
target=*
}
x10.basic
{
command=off
device=a11
}
!);

my $cmd = $^X.' -Iblib/lib '.($ENV{HARNESS_PERL_SWITCHES}||'').
              ' blib/script/xpl-rfxcom-rx';
my $fh;
open $fh, $cmd.' 2>&1 |' or die $!;
is(~~<$fh>, "The --rfxcom-rx parameter is required\n",
   'missing parameter content');
ok(!close $fh, 'missing parameter exit close');

sub check_sent_msg {
  my ($string) = @_;
  my $msg = shift @msg;
  while ((ref $msg->[0]) =~ /^xPL::Message::hbeat/) {
    $msg = shift @msg; # skip hbeat.* message
  }
  if (defined $string) {
    my $m = $msg->[0];
    is_deeply([split /\n/, $m->string], [split /\n/, $string],
              'message as expected - '.$m->summary);
  } else {
    is(scalar @msg, 0, 'message not expected');
  }
}
