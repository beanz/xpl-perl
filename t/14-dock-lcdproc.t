#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 27;
use t::Helpers qw/test_warn test_error test_output/;
$|=1;

use_ok('xPL::Dock','LCDproc');
use_ok('xPL::BinaryMessage');

my @msg;
sub xPL::Dock::send_aux {
  my $self = shift;
  my $sin = shift;
  push @msg, [@_];
}

$ENV{XPL_HOSTNAME} = 'mytestid';
my $device = IO::Socket::INET->new(Listen => 5, LocalAddr => '127.0.0.1:0');
ok($device, 'creating fake tcp lcdproc client');
my $sel = IO::Select->new($device);
my $port = $device->sockport();
my $xpl;

{
  local $0 = 'dingus';
  local @ARGV = ('-v',
                 '--interface', 'lo',
                 '--define', 'hubless=1',
                 '--lcdproc-verbose',
                 '--lcdproc-server' => '127.0.0.1:'.$port);
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock lcdproc client');
ok($sel->can_read, 'lcdproc device ready to accept');
my $client = $device->accept;
ok($client, 'client accepted');
my $client_sel = IO::Select->new($client);

my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::LCDproc', 'plugin has correct type');

$xpl->main_loop(1);

my $buf = '';
check_line($client_sel, $client, $buf, "hello");
print $client "connect LCDproc 0.5dev ".
  "protocol 0.3 lcd wid 20 hgt 4 cellwid 5 cellhgt 8\n";

is(test_output(sub { $xpl->main_loop(1) }, \*STDOUT),
   q{Connected to LCD (20x4)
queued: screen_add xplosd
sending: screen_add xplosd
queued: screen_set xplosd -name xplosd
queued: screen_set xplosd -priority hidden
},
   'connected message');

check_line($client_sel, $client, $buf, "screen_add xplosd");
print $client "success\n";
is(test_output(sub { $xpl->main_loop(1) }, \*STDOUT),
   "sending: screen_set xplosd -name xplosd\n", 'screen_set name');

check_line($client_sel, $client, $buf, "screen_set xplosd -name xplosd");
print $client "success\n";
is(test_output(sub { $xpl->main_loop(1) }, \*STDOUT),
   "sending: screen_set xplosd -priority hidden\n", 'screen_set priority');

check_line($client_sel, $client, $buf, "screen_set xplosd -priority hidden");
#print $client "huh?n"; # let's pretend that failed
#is(test_warn(sub { $xpl->main_loop(1) }), '', 'nothing to write');

sub check_line {
  ok($_[0]->can_read(0.2), "check_line '$_[3]' - can read");
  is((sysread $_[1], $_[2], 512, length $_[2]), 1+(length $_[3]),
     "check_line '$_[3]' - length");
  ok((scalar $_[2]=~s/^(.*)\n//), "check_line '$_[3]' - got a line");
  is($1, $_[3], "check_line '$_[3]' - correct line");
}

sub check_sent_msg {
  my ($class, $color, $base) = @_;
  my $msg = shift @msg;
  while (ref $msg->[0]) {
    $msg = shift @msg; # skip hbeat.* message
  }
  my %m = @{$msg};
  is($m{class}, 'dmx.confirm', 'dmx.confirm message sent - '.$color);
  is($m{body}->{value}, $color, 'dmx.confirm has correct value - '.$color);
  is($m{body}->{base}, $base, 'dmx.confirm has correct base - '.$color);
}
