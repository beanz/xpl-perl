#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use t::Helpers qw/test_warn test_error test_output wait_for_callback/;
use t::Dock qw/check_sent_messages/;
$|=1;

BEGIN {
  require Test::More;
  eval { require AnyEvent::RFXCOM::RX; import AnyEvent::RFXCOM::RX; };
  if ($@) {
    import Test::More skip_all => 'No AnyEvent::RFXCOM::RX module: '.$@;
  }
  import Test::More;
}

use_ok('xPL::Dock','RFXComRX');
use_ok('xPL::IORecord::Hex');

$ENV{XPL_HOSTNAME} = 'default';
my $device = IO::Socket::INET->new(Listen => 5, LocalAddr => '127.0.0.1:0');
ok($device, 'creating fake tcp serial client');
my $sel = IO::Select->new($device);
my $port = $device->sockport();
my $xpl;

{
  local $0 = 'rftest';
  local @ARGV = ('-v',
                 '--interface', 'lo',
                 '--define', 'hubless=1',
                 '--rfxcom-rx-tty', '127.0.0.1:'.$port);
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
ok($sel->can_read(0.5), 'device ready to accept');
my $client = $device->accept;
ok($client, 'client accepted');
my $client_sel = IO::Select->new($client);

my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::RFXComRX', 'plugin has correct type');

foreach my $r (['F020' => '4d26'], ['F041' => '41'], ['F02a' => '41']) {
  my ($recv,$send) = @$r;
  AnyEvent->one_event;
  AnyEvent->one_event;
  ok($client_sel->can_read(0.5), 'device receive a message - '.$recv);
  my $buf = '';
  is((sysread $client, $buf, 64), length($recv)/2,
     'read is correct size - '.$recv);
  my $m = xPL::IORecord::Hex->new(raw => $buf);
  is($m, lc $recv, 'content is correct - '.$recv);

  print $client pack 'H*', $send;

  wait_for_message();

  my $res = $plugin->{_last_res};
  is(sprintf("%02x%s", $res->header_byte, $res->hex_data),
     $send, 'read response - '.$send);
}

sub wait_for_message {
  my ($self) = @_;
  undef $plugin->{_got_message};
  do {
    AnyEvent->one_event;
  } until ($plugin->{_got_message});
}

my $tests = 21;
my $dir = 't/rf';
my $case = $ENV{XPL_RFXCOM_RX_TESTCASE};
opendir my $dh, $dir or die "Failed to open $dir: $!";
foreach my $f (sort readdir $dh) {
  next if ($case && $f !~ /$case/o);
  next unless ($f =~ /^(.*)\.txt$/);
  my $name = $1;
  my $fp = $dir.'/'.$f;
  open my $fh, '<', $fp or die "Failed to open $fp: $!";
  my ($message, $length, $count, $string, $warnings, $flags);
  {
    local $/ = "\n\n";
    ($message, $length, $count, $string, $warnings, $flags) = <$fh>;
  }
  close $fh;
  $message =~ s/\n+$//;
  $length =~ s/\n+$//;;
  $count =~ s/ messages\n+$//;;
  next if ($count == 0);
  $string =~ s/\n+$//;
  # TOFIX?
  $string =~ s/string=(?:comfortable|normal|wet)\n//g;
  $string =~ s/risk=(?:medium|dangerous|low)\n//g;
  $string =~ s/average=(?:\d\.\d|\d)\n//g;
  $string =~ s/base_device=00f0\n//g;
  $string =~ s/unknown=3d\n//g;
  $string =~ s/restore=true\n//g;
  $string =~ s/forecast=(?:unknown|partly)\n//g;
  $string =~ s/event=alive\n//g;
  $string =~ s/event=event\n//g;
  $string =~ s/repeat=true\n//g;
  $string =~ s/device=rtgr328n\.4d\n//g if ($string =~ /datetime.basic\n/);

  $string =~ s/low-battery=true\n//g;
  $warnings && $warnings =~ s/\n+$//;
  if ($flags && $flags =~ s/^pause\s*//) {
    select undef, undef, undef, 1.1;
  }
  if ($flags && $flags =~ s/^clear\s*//) {
    # clear unit code cache and try again - trash non-X10 decoders, nevermind
    $_->{unit_cache} = {} foreach (@{$plugin->{rx}->{plugins}});
    $plugin->{rx}->{_cache} = {};
  }
  print $client pack 'H*', $message;
  my $output;
  my $warnings_got =
    test_warn(sub {
                $output = test_output(sub { wait_for_message() }, \*STDOUT)
              });
  check_sent_messages($name => $string);
  $warnings_got && $warnings_got =~ s/\n+$//;
  undef $warnings if ($warnings && $warnings eq 'none');
  is($warnings_got, $warnings, 'warnings - '.$name);
  $tests += 2;
}

# The begin block is global of course but this is where it is really used.
BEGIN{
  *CORE::GLOBAL::exit = sub { die "EXIT\n" };
  require Pod::Usage; import Pod::Usage;
}
{
  local @ARGV = ('-v', '--interface', 'lo', '--define', 'hubless=1');
  is(test_output(sub {
                   eval { $xpl = xPL::Dock->new(port => 0, name => 'rftest'); }
                 }, \*STDOUT),
     q{Listening on 127.0.0.1:3865
Sending on 127.0.0.1
The --rfxcom-rx-tty parameter is required
or the value can be given as a command line argument
}, 'missing parameter');
}

done_testing($tests);
