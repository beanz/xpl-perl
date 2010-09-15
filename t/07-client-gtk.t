#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2007 by Mark Hindess

use strict;
use Socket;

BEGIN {
  require Test::More;
  unless (exists $ENV{DISPLAY}) {
    import Test::More skip_all => 'No X11 DISPLAY defined';
    exit;
  }
  eval {
    require Gtk2; import Gtk2 -init;
  };
  if ($@) {
    import Test::More skip_all => 'No Gtk2 perl module installed';
    exit;
  }
  import Test::More tests => 11;
}

use FileHandle;
use t::Helpers qw/test_error test_warn/;
$|=1;

use_ok("xPL::Gtk2Client");


my $errors;
{
  # This is to override to kill the main loop
  package xPL::Gtk2ClientExit;
  use base qw/xPL::Gtk2Client/;
  sub dispatch_timer {
    my $self = shift;
    $self->SUPER::dispatch_timer(@_);
    Gtk2->main_quit;
  }
}
my $event_loop = $xPL::Listener::EVENT_LOOP;

# we bind a fake hub to make sure we don't accidentally hit a live
# udp port
my $hs;
socket($hs, PF_INET, SOCK_DGRAM, getprotobyname('udp'));
setsockopt $hs, SOL_SOCKET, SO_BROADCAST, 1;
#setsockopt $hs, SOL_SOCKET, SO_REUSEADDR, 1;
binmode $hs;
bind($hs, sockaddr_in(0, inet_aton("127.0.0.1"))) or
  die "Failed to bind listen socket: $!\n";
my ($fake_hub_port, $fake_hub_addr) = sockaddr_in(getsockname($hs));

my $xpl = xPL::Gtk2ClientExit->new(vendor_id => 'acme',
                                   device_id => 'dingus',
                                   ip => "127.0.0.1",
                                   broadcast => "127.255.255.255",
                                  );
ok($xpl, 'constructor');

$xpl->{_send_sin} = sockaddr_in($fake_hub_port, $fake_hub_addr);

wait_for_tick($xpl);

is($xpl->hbeat_count, 1, "correct hbeat count");
my $buf;
my $r = recv($hs, $buf, 1024, 0);
ok(defined $r, "received first hbeat");

my $hb = "xpl-stat
{
hop=1
source=".$xpl->id."
target=*
}
hbeat.app
{
interval=5
port=".$xpl->listen_port."
remote-ip=".$xpl->ip."
}
";
is($buf, $hb, "first hbeat content");

my $fh = FileHandle->new('</dev/zero');
my $called;
ok($fh, 'file handle for input testing');
$xpl->add_input(handle => $fh, callback => sub { $called++; Gtk2->main_quit; });
Gtk2->main();
is($called, 1, '/dev/zero input callback was called');
ok($xpl->remove_input($fh), '/dev/zero input removed');
undef $called;
$xpl->add_timer(id => 'test',
                callback => sub { $called++; Gtk2->main_quit; 1; },
                timeout => '0.01');
Gtk2->main();
is($called, 1, 'timer callback was called');
ok($xpl->remove_timer('test'), 'timer removed');

is(test_warn(sub { $xpl->remove_input('test') }),
   q{xPL::Gtk2ClientExit->_}.$event_loop.q{_remove_input: input 'test' not registered},
   'remove_input warning case');

sub wait_for_tick {
  my $xpl = shift;

  do { Gtk2->main(); } until ($xpl->hbeat_count == 1);
}

sub fake_hub_response {
  my $xpl = shift;
  my $save_sin = $xpl->{_send_sin};
  # hack send_sin so we can send some responses to ourself
  $xpl->{_send_sin} = sockaddr_in($xpl->listen_port, inet_aton($xpl->ip));
  $xpl->send(@_);
  $xpl->{_send_sin} = $save_sin;
}
