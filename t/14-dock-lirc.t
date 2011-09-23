#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 15;
use Time::HiRes;
use Cwd;
use t::Helpers qw/test_warn test_error test_output wait_for_callback/;
no warnings qw/deprecated/;
$|=1;

use_ok('xPL::Dock','LIRC');

my @msg;
sub xPL::Dock::send_aux {
  my $self = shift;
  my $sin = shift;
  push @msg, [@_];
}

$ENV{XPL_HOSTNAME} = 'mytestid';
my $device = IO::Socket::INET->new(Listen => 5, LocalAddr => '127.0.0.1:0');
ok($device, 'creating fake tcp lirc client');
my $sel = IO::Select->new($device);
my $port = $device->sockport();
my $xpl;

{
  local $0 = 'dingus';
  local @ARGV = ('-v',
                 '--interface', 'lo',
                 '--define', 'hubless=1',
                 '--lirc-verbose',
                 '--lirc-server' => '127.0.0.1:'.$port);
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock lirc client');
ok($sel->can_read(0.5), 'lirc device ready to accept');
my $client = $device->accept;
ok($client, 'client accepted');
my $client_sel = IO::Select->new($client);

my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::LIRC', 'plugin has correct type');

$client->print("ffff423000000000 00 STOP vcr0081\n");

wait_for_callback($xpl, input => $plugin->{_io}->input_handle);

check_sent_msg({
                message_type => 'xpl-trig',
                schema => 'remote.basic',
                body =>
                [
                 device => 'vcr0081',
                 keys => 'stop',
                ],
               }, 'checking xPL message');

$client->print("END\n");

is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "END\n", 'non-key message');
$client->close;

is(test_error(sub { $xpl->main_loop(1); }),
   "xPL::IOHandler->read: closed", 'close');

$device->close;
{
  local $0 = 'dingus';
  local @ARGV = ('-v',
                 '--interface', 'lo',
                 '--define', 'hubless=1',
                 '--lirc-verbose',
                 '--lirc-server' => '127.0.0.1:'.$port);
  is(test_error(sub { $xpl = xPL::Dock->new(port => 0); }),
     (q{xPL::IOHandler->device_open: TCP connect to '127.0.0.1:}.$port.
      q{' failed: Connection refused}),
     'connection refused');
}

my $fifo = getcwd.'/t/fifo.'.$$;
$device = IO::Socket::UNIX->new(Listen => 1, Local => $fifo);
ok($device, 'creating fake unix domain socket lirc client');
$sel = IO::Select->new($device);

{
  local $0 = 'dingus';
  local @ARGV = ('-v',
                 '--interface', 'lo',
                 '--define', 'hubless=1',
                 '--lirc-verbose',
                 '--lirc-server' => $fifo);
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock lirc client');
ok($sel->can_read(0.5), 'lirc device ready to accept');
$client = $device->accept;
ok($client, 'client accepted');
$client_sel = IO::Select->new($client);

unlink $fifo;

sub check_sent_msg {
  my ($expected, $desc) = @_;
  my $msg = shift @msg;
  while (ref $msg->[0]) {
    $msg = shift @msg; # skip hbeat.* message
  }
  my %m = @{$msg};
  is_deeply(\%m, $expected, $desc);
}
