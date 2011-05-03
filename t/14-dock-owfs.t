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

use_ok('xPL::Dock','Owfs');

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
my $xpl;
my $plugin;

{
  local $0 = 'dingus';
  local @ARGV = ('--verbose',
                 '--interface', 'lo',
                 '--define', 'hubless=1', 't/ow/1');
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
$plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::Owfs', 'plugin has correct type');

$plugin->owfs_write('28.FEFEFE000000/counters.A', 101);
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   '28.FEFEFE000000/temp/20.1
28.FEFEFE000000.0/count/101
CRC8 error rate   0.01
CRC16 error rate   0.00
1st try read success  99.99
2nd try read success   0.01
3rd try read success  54.80
        read failure -54.79
1st try write success 100.00
2nd try write success   0.00
3rd try write success   0.00
        write failure   0.00
',
   'output 1');

check_sent_msg({
                'body' => [
                           'device' => '28.FEFEFE000000',
                           'type' => 'temp',
                           'current' => '20.1',
                          ],
                'message_type' => 'xpl-trig',
                'schema' => 'sensor.basic'
               }, 'temp reported');
check_sent_msg({
                'body' => [
                           'device' => '28.FEFEFE000000.0',
                           'type' => 'count',
                           'current' => '101',
                          ],
                'message_type' => 'xpl-trig',
                'schema' => 'sensor.basic'
               }, 'count.1 reported');

$plugin->owfs_write('28.FEFEFE000000/counters.A', 102);
$plugin->owfs_write('28.FEFEFE000000/counters.B', 102);
chmod 0, 't/ow/1/28.FEFEFE000000/counters.B';

SKIP: {
  skip "Can't test read failure when running as root", 3 if ($> == 0);
  like(test_warn(sub { $plugin->owfs_reader(); }),
       qr!^Failed to read ow file, t/ow/1/28\.FEFEFE000000/counters\.B: !,
       'read failure');
  check_sent_msg({
                  'body' => [
                             'device' => '28.FEFEFE000000',
                             'type' => 'temp',
                             'current' => '20.1',
                          ],
                  'message_type' => 'xpl-stat',
                  'schema' => 'sensor.basic'
                 }, 'temp reported');
  check_sent_msg({
                  'body' => [
                             'device' => '28.FEFEFE000000.0',
                             'type' => 'count',
                             'current' => '102',
                            ],
                  'message_type' => 'xpl-trig',
                  'schema' => 'sensor.basic'
                 }, 'count.1 reported');
  unlink 't/ow/1/28.FEFEFE000000/counters.A';
  unlink 't/ow/1/28.FEFEFE000000/counters.B';
}

{
  local $0 = 'dingus';
  local @ARGV = ('--verbose',
                 '--owfs-verbose',
                 '--interface', 'lo',
                 '--define', 'hubless=1', 't/ow/2');
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
$plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::Owfs', 'plugin has correct type');

is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   '26.ABABAB000000/temp/25.8438
26.ABABAB000000/humidity/24.6653
CRC8 error rate   0.00
CRC16 error rate   0.00
1st try read success 100.00
2nd try read success   0.00
3rd try read success   0.00
        read failure   0.00
1st try write success 100.00
2nd try write success   0.00
3rd try write success   0.00
        write failure   0.00
',
   'output 2');

check_sent_msg({
                'body' => [
                           'device' => '26.ABABAB000000',
                           'type' => 'temp',
                           'current' => '25.8438',
                          ],
                'message_type' => 'xpl-trig',
                'schema' => 'sensor.basic'
               }, 'temp reported');
check_sent_msg({
                'body' => [
                           'device' => '26.ABABAB000000',
                           'type' => 'humidity',
                           'current' => '24.6653',
                          ],
                'message_type' => 'xpl-trig',
                'schema' => 'sensor.basic'
               }, 'humidity reported');

my $file = 't/ow/2/05.CFCFCF000000/PIO';
unlink $file;
$xpl->dispatch_xpl_message(
  xPL::Message->new(message_type => 'xpl-cmnd',
                    schema => 'control.basic',
                    head => { source => 'acme-owfs.test' },
                    body =>
                    [
                     device => '05.CFCFCF000000',
                     type => 'output',
                     current => 'low',
                    ]));
is(read_file($file), '0', 'output set low');
unlink $file;

$xpl->dispatch_xpl_message(
  xPL::Message->new(message_type => 'xpl-cmnd',
                    schema => 'control.basic',
                    head => { source => 'acme-owfs.test' },
                    body =>
                    [
                     device => '05.CFCFCF000000',
                     type => 'output',
                     current => 'high',
                    ]));
is(read_file($file), '1', 'output set high');
unlink $file;

is(test_output(sub {
  $xpl->dispatch_xpl_message(
    xPL::Message->new(message_type => 'xpl-cmnd',
                      schema => 'control.basic',
                      head => { source => 'acme-owfs.test' },
                      body =>
                      [
                       device => '05.CFCFCF000000',
                       type => 'output',
                       current => 'pulse',
                      ])); }, \*STDERR),
   'Writing 1 to 05.CFCFCF000000/PIO
Writing 0 to 05.CFCFCF000000/PIO
',
   'debug output');
is(read_file($file), '0', 'output set pulse');
unlink $file;

is(test_warn(sub {
  $xpl->dispatch_xpl_message(
    xPL::Message->new(message_type => 'xpl-cmnd',
                      schema => 'control.basic',
                      head => { source => 'acme-owfs.test' },
                      body =>
                      [
                       device => '05.DFDFDF000000',
                       type => 'output',
                       current => 'high',
                      ])); }),
   "Failed to write ow file, 05.DFDFDF000000/PIO: No such file or directory\n",
   'file write warning');

is(test_warn(sub {
  $xpl->dispatch_xpl_message(
    xPL::Message->new(message_type => 'xpl-cmnd',
                      schema => 'control.basic',
                      head => { source => 'acme-owfs.test' },
                      body =>
                      [
                       device => '05.CFCFCF000000',
                       type => 'output',
                       current => 'toggle',
                      ])); }),
   "Unsupported setting: toggle\n", 'output set toggle - unsupported');

is(test_output(sub {
  $xpl->dispatch_xpl_message(
    xPL::Message->new(message_type => 'xpl-cmnd',
                      schema => 'control.basic',
                      head => { source => 'acme-owfs.test' },
                      body =>
                      [
                       device => 'o01',
                       type => 'output',
                       current => 'high',
                      ])); }, \*STDERR),
   '', 'no debug output - unknown device');

{
  local $0 = 'dingus';
  local @ARGV = ('--verbose',
                 '--owfs-verbose',
                 '--interface', 'lo',
                 '--define', 'hubless=1', 't/ow/3');
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
$plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::Owfs', 'plugin has correct type');
is(test_warn(sub { $xpl->main_loop(1); }),
   'Failed to open ow dir, t/ow/3: No such file or directory
No devices found?
', 'invalid mount');

is(test_warn(sub { xPL::Dock::Owfs::read_ow_file('t/ow/3/invalid'); }),
   "Failed to read ow file, t/ow/3/invalid: No such file or directory\n",
   'file read warning');

sub read_file {
  my $file = shift;
  my $fh;
  open $fh, '<'.$file or return undef;
  my $l = <$fh>;
  $fh->close;
  chomp $l;
  return $l;
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
