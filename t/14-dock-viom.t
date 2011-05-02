#!#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 63;
use t::Helpers qw/test_warn test_error test_output wait_for_callback/;
$|=1;

use_ok('xPL::Dock','VIOM');

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
ok($device, 'creating fake tcp serial client');
my $sel = IO::Select->new($device);
my $port = $device->sockport();
my $xpl;

{
  local $0 = 'dingus';
  local @ARGV = ('--verbose',
                 '--viom-verbose', '--viom-verbose',
                 '--interface', 'lo',
                 '--define', 'hubless=1',
                 '--viom-tty', '127.0.0.1:'.$port);
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
ok($sel->can_read(0.5), 'device ready to accept');
my $client = $device->accept;
ok($client, 'client accepted');
my $client_sel = IO::Select->new($client);

my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::VIOM', 'plugin has correct type');

my $buf;

ok($client_sel->can_read(0.5), 'device receive a message - CSV');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - CSV');
is($buf, "CSV\r\n", 'content is correct - CSV');
print $client "Software Version 1.02+1.01\r\n";
my $output = '';
$output =
  test_output(sub {
                wait_for_callback($xpl,
                                  input => $plugin->{_io}->input_handle)
              }, \*STDOUT);
ok($output =~ s/\QSoftware Version 1.02+1.01\E\n//, 'output has version info');

ok($client_sel->can_read(0.5), 'device receive a message - CIC1');
$buf = '';
is((sysread $client, $buf, 64), 6, 'read is correct size - CIC1');
is($buf, "CIC1\r\n", 'content is correct - CIC1');
print $client "Input Change Reporting is On\r\n";
$output .=
  test_output(sub {
                wait_for_callback($xpl,
                                  input => $plugin->{_io}->input_handle)
              }, \*STDOUT);
ok($output =~ s/Input Change Reporting is On\n//, 'output has reporting on');

ok($client_sel->can_read(0.5), 'device receive a message - 1st');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - 1st');
my $second =
  $buf eq "CIN\r\n" ? "COR\r\n" : ($buf eq "COR\r\n" ? "CIN\r\n" : undef);
ok(defined $second, 'content is correct - 1st');
print $client "Output 1 Inactive\r\n";
$output .=
  test_output(sub {
                wait_for_callback($xpl,
                                  input => $plugin->{_io}->input_handle)
              }, \*STDOUT);
ok($output =~ s/Output 1 Inactive\n//, 'output has output 1 inactive');
ok($output =~ s/sending: CIC1\n//, 'output has sending CIC1');
ok($output =~ s/queued: COR\n//, 'output has queued COR');
ok($output =~ s/sending: COR\n//, 'output has sending COR');
ok($output =~ s/queued: CIN\n//, 'output has queued CIN');
ok($output =~ s/sending: CIN\n//, 'output has sending CIN');

ok($client_sel->can_read(0.5), 'device receive a message - 2nd');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - 2nd');
is($buf, $second, 'content is correct - 2nd');
print $client "Input 1 Inactive\r\n";
is(test_output(sub {
                 wait_for_callback($xpl,
                                   input => $plugin->{_io}->input_handle)
               }, \*STDOUT),
   "Input 1 Inactive\n",
   'read response - 2nd');

$plugin->{_verbose} = 0;
print $client "Input 1 Inactive\r\n";
is(test_output(sub {
                 wait_for_callback($xpl,
                                   input => $plugin->{_io}->input_handle)
               }, \*STDOUT),
   '',
   'read response - Input inactive(unchanged)');
$plugin->{_verbose} = 2;

print $client "Input 1 Active\r\n";
is(test_output(sub {
                 wait_for_callback($xpl,
                                   input => $plugin->{_io}->input_handle)
               }, \*STDOUT),
   "Input 1 Active\n",
   'read response - Input active(changed)');
# no message because it was regular update/sync not a status change
check_sent_msg(undef, , 'i01 high');

print $client "0000000000000000\r\n";
is(test_output(sub {
                 wait_for_callback($xpl,
                                   input => $plugin->{_io}->input_handle)
               }, \*STDOUT),
   "i01/input/low\n0000000000000000\n",
   'read response - input changed state');
check_sent_msg({
                message_type => 'xpl-trig',
                schema => 'sensor.basic',
                body =>
                [ device => 'i01', type => 'input', current => 'low' ],
               }, 'i01 low');

print $client "1000000000000000\r\n";
$xpl->{_verbose} = 0;
$plugin->{_verbose} = 0;
is(test_output(sub {
                 wait_for_callback($xpl,
                                   input => $plugin->{_io}->input_handle)
               }, \*STDOUT),
   '', 'read response - input changed state');
check_sent_msg({
                message_type => 'xpl-trig',
                schema => 'sensor.basic',
                body =>
                [ device => 'i01', type => 'input', current => 'high' ],
               }, 'i01 low');
$plugin->{_verbose} = 2;

my $msg = xPL::Message->new(message_type => 'xpl-cmnd',
                            schema => 'control.basic',
                            head => { source => 'acme-viom.test' },
                            body =>
                            [
                             type => 'output',
                             device => 'o01',
                             current => 'high',
                            ]);
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read(0.5), 'device receive a message - o01/high');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - o01/high');
is($buf, "XA1\r\n", 'content is correct - o01/high');
print $client "Output 1 On Period\r\n";
is(test_output(sub {
                 wait_for_callback($xpl,
                                   input => $plugin->{_io}->input_handle)
               }, \*STDOUT),
   "Output 1 On Period\n",
   'read response - o01/high');

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         schema => 'control.basic',
                         head => { source => 'acme-viom.test' },
                         body =>
                         [
                          type => 'output',
                          device => 'o01',
                          current => 'low',
                         ]);
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read(0.5), 'device receive a message - o01/low');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - o01/low');
is($buf, "XB1\r\n", 'content is correct - o01/low');
print $client "Output 1 Inactive\r\n";
is(test_output(sub {
                 wait_for_callback($xpl,
                                   input => $plugin->{_io}->input_handle)
               }, \*STDOUT),
   "Output 1 Inactive\n", 'read response - o01/low');

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         schema => 'control.basic',
                         head => { source => 'acme-viom.test' },
                         body =>
                         [
                          type => 'output',
                          device => 'o01',
                          current => 'pulse',
                         ]);
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read(0.5), 'device receive a message - o01/pulse');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - o01/pulse');
is($buf, "XA1\r\n", 'content is correct - o01/pulse');
print $client "Output 1 On Period\r\n";
$output =
  test_output(sub {
                wait_for_callback($xpl,
                                  input => $plugin->{_io}->input_handle)
              }, \*STDOUT);
ok($output =~ s/Output 1 On Period\n//, 'output has output 1 on period');
ok($output =~ s/sending: XB1\n//, 'output has sending XB1');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - o01/pulse');
is($buf, "XB1\r\n", 'content is correct - o01/pulse');
print $client "Output 1 Inactive\r\n";
is(test_output(sub {
                 wait_for_callback($xpl,
                                   input => $plugin->{_io}->input_handle)
               }, \*STDOUT),
   "Output 1 Inactive\n", 'read response - o01/pulse');

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         schema => 'control.basic',
                         head => { source => 'acme-viom.test' },
                         body =>
                         [
                          type => 'output',
                          device => 'o01',
                          current => 'toggle',
                         ]);
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read(0.5), 'device receive a message - o01/toggle');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - o01/toggle');
is($buf, "XA1\r\n", 'content is correct - o01/toggle');
print $client "\r\nOutput 1 On Period\r\n"; # extra new line should be ignored
is(test_output(sub {
                 wait_for_callback($xpl,
                                   input => $plugin->{_io}->input_handle)
               }, \*STDOUT),
   "Output 1 On Period\n",
   'read response - o01/toggle');

$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read(0.5), 'device receive a message - o01/toggle(off)');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - o01/toggle(off)');
is($buf, "XB1\r\n", 'content is correct - o01/toggle(off)');
print $client "Output 1 Inactive\r\n";
is(test_output(sub {
                 wait_for_callback($xpl,
                                   input => $plugin->{_io}->input_handle)
               }, \*STDOUT),
   "Output 1 Inactive\n",
   'read response - o01/toggle(off)');

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         schema => 'control.basic',
                         head => { source => 'acme-viom.test' },
                         body =>
                         [
                          type => 'output',
                          device => 'output01',
                          current => 'toggle',
                         ]);
$xpl->dispatch_xpl_message($msg);
ok(!$client_sel->can_read(0.5), 'device receive no message - output1/toggle');

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         schema => 'control.basic',
                         head => { source => 'acme-viom.test' },
                         body =>
                         [
                          type => 'output',
                          device => 'o01',
                          current => 'fire',
                         ]);
is(test_warn(sub { $xpl->dispatch_xpl_message($msg) }),
   "Unsupported setting: fire\n", 'invalid setting');
ok(!$client_sel->can_read(0.5), 'device receive no message - o01/fire');

# The begin block is global of course but this is where it is really used.
BEGIN{
  *CORE::GLOBAL::exit = sub { die "EXIT\n" };
  require Pod::Usage; import Pod::Usage;
}
{
  local @ARGV = ('--verbose', '--interface', 'lo', '--define', 'hubless=1');
  is(test_output(sub {
                   eval { $xpl = xPL::Dock->new(port => 0, name => 'dingus'); }
                 }, \*STDOUT),
     q{Listening on 127.0.0.1:3865
Sending on 127.0.0.1
The --viom-tty parameter is required
or the value can be given as a command line argument
}, 'missing parameter');
}

sub check_sent_msg {
  my ($expected, $desc) = @_;
  my $msg = shift @msg;
  while ($msg->[0] && ref $msg->[0] eq 'xPL::Message' &&
         $msg->[0]->schema =~ /^hbeat\./) {
    $msg = shift @msg; # skip hbeat.* message
  }
  if (defined $expected) {
    my %m = @{$msg};
    is_deeply(\%m, $expected, 'message as expected - '.$desc);
  } else {
    is(scalar @msg, 0, 'message not expected - '.$desc);
  }
}
