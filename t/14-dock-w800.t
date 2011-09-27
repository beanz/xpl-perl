#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use t::Helpers qw/test_warn test_error test_output wait_for_callback/;
use t::Dock qw/check_sent_message/;
$|=1;

BEGIN {
  require Test::More;
  eval { require AnyEvent::W800; import AnyEvent::W800; };
  if ($@) {
    import Test::More skip_all => 'No AnyEvent::W800 module: '.$@;
  }
  import Test::More tests => 12;
}

use_ok('xPL::Dock','W800');

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
                 '--w800-tty', '127.0.0.1:'.$port);
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
ok($sel->can_read(0.5), 'device ready to accept');
my $client = $device->accept;
ok($client, 'client accepted');
my $client_sel = IO::Select->new($client);

my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::W800', 'plugin has correct type');

print $client pack 'H*', '649b08f7';
is(test_output(sub { wait_for_message() }, \*STDOUT),
   "xpl-trig/x10.basic: bnz-dingus.mytestid -> * on/a11\n",
   'read response - a11/on');
check_sent_message('a11/on' => q!xpl-trig
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
$plugin->{_verbose} = 1;
print $client pack 'H*', '649b08f7';
is(test_output(sub { wait_for_message() }, \*STDOUT),
   "Processed: master x10 20.649b08f7(dup): x10/a11/on\n",
   'read response - a11/on duplicate');
check_sent_message('a11/on duplicate');

# The begin block is global of course but this is where it is really used.
BEGIN{
  *CORE::GLOBAL::exit = sub { die "EXIT\n" };
  require Pod::Usage; import Pod::Usage;
}
{
  local @ARGV = ('-v', '--interface', 'lo', '--define', 'hubless=1');
  is(test_output(sub {
                   eval { $xpl = xPL::Dock->new(port => 0, name => 'dingus'); }
                 }, \*STDOUT),
     q{Listening on 127.0.0.1:3865
Sending on 127.0.0.1
The --w800-tty parameter is required
or the value can be given as a command line argument
}, 'missing parameter');
}

sub wait_for_message {
  my ($self) = @_;
  undef $plugin->{_got_message};
  do {
    AnyEvent->one_event;
  } until ($plugin->{_got_message});
 }
