#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 113;
use Time::HiRes;
use t::Helpers qw/test_warn test_error test_output/;
no warnings qw/deprecated/;
$|=1;

use_ok('xPL::Dock','LCDproc');

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
ok($sel->can_read(0.5), 'lcdproc device ready to accept');
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
queued: screen_set xplosd -name xplosd
queued: screen_set xplosd -priority hidden
sending: screen_add xplosd
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
print $client "huh? just testing failure warning\n";
is(test_warn(sub { $xpl->main_loop(1) }),
   "Failed. Sent: screen_set xplosd -priority hidden\n".
   "got: huh? just testing failure warning\n", 'failure warning');

print $client "just testing failure warning\n";
is(test_warn(sub { $xpl->main_loop(1) }),
   "Failed. Sent: *nothing*\ngot: just testing failure warning\n",
   'failure warning - not waiting');

$xpl->dispatch_xpl_message(xPL::Message->new(message_type => 'xpl-cmnd',
                                             head =>
                                             {
                                              source => 'acme-lcdproc.test',
                                             },
                                             schema=> 'osd.basic',
                                             body =>
                                             [
                                              row => 2,
                                              'command' => 'clear',
                                              'text' => 'test',
                                             ]));

foreach my $r (['widget_add xplosd row2 string' =>
                'sending: widget_set xplosd row2 1 2 "test"'],
               ['widget_set xplosd row2 1 2 "test"' =>
                'sending: screen_set xplosd -priority alert'],
               ['screen_set xplosd -priority alert' =>
                ''],
              ) {
  my ($input, $output) = @$r;
  check_line($client_sel, $client, $buf, $input);
  print $client "success\n";
  is(test_output(sub { $xpl->main_loop(1) }, \*STDOUT),
     ($output ? $output."\n" : ''), "output '$input'");
}

is(test_output(sub { $plugin->clear_row(1) }, \*STDOUT),
   '', 'clear row');

$xpl->dispatch_xpl_message(xPL::Message->new(message_type => 'xpl-cmnd',
                                             head =>
                                             {
                                              source => 'acme-lcdproc.test',
                                             },
                                             schema=> 'osd.basic',
                                             body =>
                                             [
                                              # row intentionally out of range
                                              row => 20,
                                              'command' => 'clear',
                                              'text' =>
                                                'this is a long string',
                                             ]));

foreach my $r (['screen_set xplosd -priority hidden' =>
                'sending: widget_del xplosd row2'],
               ['widget_del xplosd row2' =>
                'sending: widget_add xplosd row1 scroller'],
               ['widget_add xplosd row1 scroller' =>
                'sending: widget_set xplosd row1 1 1 20 1 h 2 '.
                '"this is a long string"'],
               ['widget_set xplosd row1 1 1 20 1 h 2 "this is a long string"'=>
                'sending: screen_set xplosd -priority alert'],
               ['screen_set xplosd -priority alert' =>
                ''],
              ) {
  my ($input, $output) = @$r;
  check_line($client_sel, $client, $buf, $input);
  print $client "success\n";
  is(test_output(sub { $xpl->main_loop(1) }, \*STDOUT),
     ($output ? $output."\n" : ''), "output '$input'");
}

$xpl->dispatch_xpl_message(xPL::Message->new(message_type => 'xpl-cmnd',
                                             head =>
                                             {
                                              source => 'acme-lcdproc.test',
                                             },
                                             schema=> 'osd.basic',
                                             body =>
                                             [
                                              # row intentionally out of range
                                              row => -1,
                                              'command' => 'write',
                                              'text' => 'short string',
                                              delay => 60,
                                             ]));

ok($xpl->timer_next('row1') <= (Time::HiRes::time + $plugin->delay),
   'max delay used');

foreach my $r (['widget_del row1' =>
                'sending: widget_add xplosd row1 string'],
               ['widget_add xplosd row1 string' =>
                'sending: widget_set xplosd row1 1 1 "short string"'],
               ['widget_set xplosd row1 1 1 "short string"' =>
                ''],
              ) {
  my ($input, $output) = @$r;
  check_line($client_sel, $client, $buf, $input);
  print $client "success\n";
  is(test_output(sub { $xpl->main_loop(1) }, \*STDOUT),
     ($output ? $output."\n" : ''), "output '$input'");
}

$xpl->dispatch_xpl_message(xPL::Message->new(message_type => 'xpl-cmnd',
                                             head =>
                                             {
                                              source => 'acme-lcdproc.test',
                                             },
                                             schema=> 'osd.basic',
                                             body =>
                                             [
                                              'command' => 'write',
                                              'text' =>
                                                'another short one',
                                              delay => 0.1,
                                             ]));

foreach my $r (['widget_set xplosd row1 1 1 "another short one"' => '']) {
  my ($input, $output) = @$r;
  check_line($client_sel, $client, $buf, $input);
  print $client "success\n";
  is(test_output(sub { $xpl->main_loop(1) }, \*STDOUT),
     ($output ? $output."\n" : ''), "output '$input'");
}

do {
  $xpl->main_loop(1);
} while ($xpl->exists_timer('row1'));

check_line($client_sel, $client, $buf, 'widget_del xplosd row1');
print $client "success\n";
$xpl->main_loop(1);

$xpl->dispatch_xpl_message(xPL::Message->new(message_type => 'xpl-cmnd',
                                             head =>
                                             {
                                              source => 'acme-lcdproc.test',
                                             },
                                             schema=> 'osd.basic',
                                             body =>
                                             [
                                              'command' => 'clear',
                                             ]));

foreach my $r (['screen_set xplosd -priority hidden' => '']) {
  my ($input, $output) = @$r;
  check_line($client_sel, $client, $buf, $input);
  print $client "success\n";
  is(test_output(sub { $xpl->main_loop(1) }, \*STDOUT),
     ($output ? $output."\n" : ''), "output '$input'");
}

print $client "connect LCDproc 0.2 protocol 0.2 lcd\n";
is(test_warn(sub { $xpl->main_loop(1) }),
   "LCDproc daemon protocol 0.2 not 0.3 as expected.\n",
   'protocol warning');

$xpl->cleanup;

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
ok($sel->can_read(0.5), 'lcdproc device ready to accept');
$client = $device->accept;
ok($client, 'client accepted');
$client_sel = IO::Select->new($client);

$plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::LCDproc', 'plugin has correct type');

$xpl->main_loop(1);

$buf = '';
check_line($client_sel, $client, $buf, "hello");
print $client "connect LCDproc 0.5dev ".
  "proto 0.1 lcd cellwid 5 cellhgt 8\n";

is(test_output(sub { $xpl->main_loop(1) }, \*STDOUT),
   q{Connected to LCD (?x?)
queued: screen_add xplosd
queued: screen_set xplosd -name xplosd
queued: screen_set xplosd -priority hidden
sending: screen_add xplosd
},
   'connected message - no dimensions');

$device->close;
{
  local $0 = 'dingus';
  local @ARGV = ('-v',
                 '--interface', 'lo',
                 '--define', 'hubless=1',
                 '--lcdproc-verbose',
                 '--lcdproc-server' => '127.0.0.1:'.$port);
  is(test_error(sub { $xpl = xPL::Dock->new(port => 0); }),
     (q{xPL::IOHandler->device_open: TCP connect to '127.0.0.1:}.$port.
      q{' failed: Connection refused}),
     'connection refused');
}

is(test_output(
     sub {
       $xpl->dispatch_xpl_message(xPL::Message->new(message_type => 'xpl-cmnd',
                                             head =>
                                             {
                                              source => 'acme-lcdproc.test',
                                             },
                                             schema=> 'osd.basic',
                                             body =>
                                             [
                                              'command' => 'write',
                                              'text' => 'a string',
                                             ]));
     }, \*STDOUT),
   (qq{queued: widget_add xplosd row1 string\n}.
    qq{queued: widget_set xplosd row1 1 1 "a string"\n}.
    qq{queued: screen_set xplosd -priority alert\n}),
   'write without dimensions');
is(test_output(
     sub {
       $xpl->dispatch_xpl_message(xPL::Message->new(message_type => 'xpl-cmnd',
                                             head =>
                                             {
                                              source => 'acme-lcdproc.test',
                                             },
                                             schema=> 'osd.basic',
                                             body =>
                                             [
                                              row => 2,
                                              'command' => 'clear',
                                              'text' => 'another string',
                                             ]));
     }, \*STDOUT),
   (qq{queued: screen_set xplosd -priority hidden\n}.
    qq{queued: widget_del xplosd row1\n}.
    qq{queued: widget_add xplosd row1 string\n}.
    qq{queued: widget_set xplosd row1 1 1 "another string"\n}.
    qq{queued: screen_set xplosd -priority alert\n}),
   'clear without dimensions');

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
