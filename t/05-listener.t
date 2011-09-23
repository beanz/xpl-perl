#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2009 by Mark Hindess

use strict;
use Test::More tests => 163;
use t::Helpers qw/test_error test_warn test_output/;
use File::Temp qw/tempfile/;
use Socket;
use Time::HiRes;
no warnings qw/deprecated/;
$|=1;

my $timeout = 0.25;
use_ok("xPL::Listener");

my $event_loop = $xPL::Listener::EVENT_LOOP;

{ # normally only clients have an identity but we'll need one to test
  # the self_skip option on xPL callbacks
  package MY::Listener;
  use base 'xPL::Listener';
  sub id { "acme-clock.dingus" };
  1;
}

my $xpl = MY::Listener->new(ip => "127.0.0.1",
                            broadcast => "127.0.0.1",
                            verbose => 1,
                           );

my @methods =
  (
   [ 'ip', "127.0.0.1", ],
   [ 'broadcast', "127.0.0.1", ],
   [ 'port', 0, ],
  );
foreach my $rec (@methods) {
  my ($method, $value) = @$rec;
  is($xpl->$method, $value, "$method method");
}

ok($xpl->module_available('strict'), "module available already used");
ok(!$xpl->module_available('sloppy'), "module not available");
ok($xpl->module_available('strict'), "module available with cache");
ok($xpl->module_available('English'), "module available");

ok($xpl->add_input(handle => \*STDIN, arguments => []), "adding input");
my @h = $xpl->inputs();
is(scalar @h, 2, "inputs count");

like(test_error(sub { $xpl->add_input(handle => \*STDIN); }),
   qr/MY::Listener->add_item: input item '[^']+' already registered/,
   "adding existing input");

ok($xpl->remove_input(\*STDIN), "removing input");

is(test_error(sub { $xpl->add_input(); }),
   "MY::Listener->_${event_loop}_add_input: requires 'handle' argument",
   "adding input without handle argument");

@h = $xpl->inputs();
is(scalar @h, 1, "inputs count");

my @t = $xpl->timers();
is(scalar @t, 0, "timers count");
my $to = $xpl->timer_minimum_timeout;
is($to, undef, "timer minimum timeout - undef");

my $cb;
$xpl->add_timer(id => 'tick', callback => sub { my %p=@_; $cb=\%p; },
                arguments => ["grr argh"],
                timeout => $timeout);

$to = $xpl->timer_minimum_timeout;
ok(defined $to && $to > 0 && $to < $timeout, "timer minimum timeout - ".$to);
ok(!defined $xpl->timer_callback_time_average('tick'),
   "timer callback time average - undef");

$xpl->main_loop(1) until ($cb);

ok(exists $cb->{id}, "timer ticked");
is($cb->{id}, 'tick', "correct timer argument");
ok($cb && exists $cb->{arguments}, "arguments passed");
is($cb->{arguments}->[0], "grr argh", "correct argument passed");
is($xpl->timer_callback_count('tick'), 1, "timer callback counter");
ok(defined $xpl->timer_callback_time_average('tick'),
   "timer callback time average");

check_stats(1,1,0);

my $now = time;
is(&{$xpl->timer_attrib('tick', 'next_fn')}($now), $now+$timeout,
   "timer next_function with positive timeout");

my $nt = $xpl->timer_next_ticks();
$to = $nt->[0] - Time::HiRes::time();
ok(defined $to && $to > 0 && $to < $timeout, "timer minimum timeout - ".$to);

# test reset_timer
$now = time + 10;
ok($xpl->reset_timer('tick', $now), "timer reset");
$nt = $xpl->timer_next_ticks();
$to = $nt->[0] - $now;
ok(defined $to && $to > 0 && $to <= $timeout, "timer reset timeout - ".$to);
ok($xpl->remove_timer('tick'), "remove timer");

is(test_warn(sub { $xpl->reset_timer('tick', $now) }),
   "MY::Listener->reset_timer: timer 'tick' not registered",
   'timer reset - warn');

$timeout = .5;
$xpl->add_timer(id => 'null', timeout => -$timeout, count => 5);
my $st = Time::HiRes::time();
$xpl->main_loop(1);
ok(Time::HiRes::time()-$st < $timeout/2,
   "quick dispatch of negative timeout");
is($xpl->timer_callback_count('null'), 1, "timer callback counter");
is($xpl->timer_attrib('null', 'count'), 4, "timer repeat count");
@t = $xpl->timers();
is(scalar @t, 1, "timers count");

$now = time;
is(&{$xpl->timer_attrib('null', 'next_fn')}($now), $now+$timeout,
   "timer next_function with negative timeout");

is(test_error(sub { $xpl->add_timer(id => 'null', timeout => -1) }),
   ref($xpl)."->add_timer: timer 'null' already exists",
   "adding existing timer");

foreach my $c (3,2,1) {
  my $tn = $xpl->timer_next('null');
  $xpl->main_loop(1) while ($xpl->timer_next('null') == $tn);
  is($xpl->timer_attrib('null', 'count'), $c, "timer repeat count");
  is($xpl->timer_callback_count('null'), 5-$c, "timer callback counter");
  @t = $xpl->timers();
  is(scalar @t, 1, "timers count");
}

my $tn = $xpl->timer_next('null');
is(test_warn(sub {
     $xpl->main_loop(1) while ($xpl->timer_attrib('null', 'count'));
   }),
   "MY::Listener->item_attrib: timer item 'null' not registered",
   'timer removed when count reaches zero');
ok(!$xpl->exists_timer('null'), 'timer removed when count reaches zero');

$xpl->add_timer(id => "no-dec-count", timeout => -1, count => 1,
                callback => sub { -1; });
$xpl->main_loop(1);
ok($xpl->exists_timer("no-dec-count"), "timer count not decremented");
is($xpl->timer_callback_count("no-dec-count"), 1, "timer callback counter");
is($xpl->timer_attrib("no-dec-count", 'count'), 1, "timer repeat count");
ok($xpl->remove_timer("no-dec-count"), "removing timer");

$xpl->add_timer(id => 'null', timeout => -1, callback => sub { undef });
$xpl->main_loop(1);
ok(!$xpl->exists_timer('null'), "timer triggered and removed on undef");

$xpl->add_timer(id => 'null', timeout => -1, count => 1);
$xpl->main_loop(1);
ok(!$xpl->exists_timer('null'), "timer triggered and removed by counter");

is(test_error(sub { $xpl->add_timer(timeout => -1) }),
   ref($xpl)."->add_timer: requires 'id' parameter",
   "adding timer with no id");

is(test_error(sub { $xpl->add_timer(id => 'null', timeout => 'tomorrow') }),
   q{xPL::Timer->new: Failed to load xPL::Timer::tomorrow: }.
     q{Can't locate xPL/Timer/tomorrow.pm in @INC},
   "adding timer with bad timeout");

is(test_error(sub { $xpl->add_timer(id => 'null') }),
   ref($xpl)."->add_timer: requires 'timeout' parameter",
   "adding existing timer");

# hacking the send socket to send to ourselves
$xpl->{_send_sin} = sockaddr_in($xpl->listen_port, inet_aton($xpl->ip));

$xpl->send(message_type => 'xpl-stat',
           head =>
           {
            source => "acme-clock.dingus",
           },
           schema => "hbeat.app",
           body =>
           [
            interval => 5,
            port => $xpl->listen_port,
            remote_ip => $xpl->ip,
           ],
          );

undef $cb;
$xpl->add_xpl_callback(id => 'hbeat',
                       callback => sub { my %p=@_; $cb=\%p },
                       filter => 'remote_ip="'.$xpl->ip.'"',
                       arguments => ["my test"],
                       self_skip => 0);

my $cb2;
$xpl->add_xpl_callback(id => 'hbeat2',
                       callback => sub { my %p=@_; $cb2=\%p },
                       filter => 'source="acme-clock\..*"',
                       arguments => ["my test"],
                       self_skip => 0);

my $cb3;
$xpl->add_xpl_callback(id => 'hbeat3',
                       callback => sub { my %p=@_; $cb3=\%p },
                       filter => 'schema="hbeat.end"',
                       arguments => ["my test"],
                       self_skip => 0);

my $cb4;
$xpl->add_xpl_callback(id => 'hbeat4',
                       callback => sub { my %p=@_; $cb4=\%p },
                       filter => 'schema="hbeat.end"',
                       arguments => ["my test"],
                       self_skip => 0);

my $cb5;
$xpl->add_xpl_callback(id => 'hbeat5',
                       callback => sub { my %p=@_; $cb5=\%p },
                       filter => { schema => sub { $_[0] eq 'hbeat.app' } },
                       arguments => ["my test"],
                       self_skip => 0);
my $cb6;
$xpl->add_xpl_callback(id => 'hbeat6',
                       callback => sub { my %p=@_; $cb6=\%p },
                       filter => { schema => sub { $_[0] eq 'hbeat.end' } },
                       arguments => ["my test"],
                       self_skip => 0);

$xpl->add_xpl_callback(id => 'null');

is(test_error(sub { $xpl->add_xpl_callback(id => 'null') }),
   ref($xpl)."->add_item: xpl_callback item 'null' already registered",
   "adding existing xpl callback");

ok(!defined $xpl->xpl_callback_callback_time_average('hbeat'),
   "xpl callback callback time average - undef");

$xpl->main_loop(1);

ok($cb && exists $cb->{message}, "message returned");
is($cb->{message}->schema, 'hbeat.app', "correct message type");
ok($cb && exists $cb->{arguments}, "arguments passed");
is($cb->{arguments}->[0], "my test", "correct argument passed");
is($xpl->xpl_callback_callback_count('hbeat'), 1, "callback counter non-zero");
ok(defined $xpl->xpl_callback_callback_time_average('hbeat'),
   "xpl callback callback time average");

ok($cb2 && exists $cb2->{message}, "message returned");
is($cb2->{message}->schema, 'hbeat.app', "correct message type");
ok($cb2 && exists $cb2->{arguments}, "arguments passed");
is($cb2->{arguments}->[0], "my test", "correct argument passed");
is($xpl->xpl_callback_callback_count('hbeat2'), 1, "callback counter non-zero");

ok(!$cb3);
is($xpl->xpl_callback_callback_count('hbeat3'), 0, "callback counter zero");

ok(!$cb4);
is($xpl->xpl_callback_callback_count('hbeat4'), 0, "callback counter zero");

ok($cb5 && exists $cb5->{message}, "message returned");
is($cb5->{message}->schema, 'hbeat.app', "correct message type");
ok($cb5 && exists $cb5->{arguments}, "arguments passed");
is($cb5->{arguments}->[0], "my test", "correct argument passed");
is($xpl->xpl_callback_callback_count('hbeat5'), 1, "callback counter non-zero");

ok(!$cb6);
is($xpl->xpl_callback_callback_count('hbeat6'), 0, "callback counter zero");

is($xpl->xpl_callback_callback_count('null'), 0, "callback counter zero");
is($xpl->input_callback_count($xpl->{_listen_sock}), 1,
   "input callback count");

ok($xpl->add_input(handle => \*STDIN, arguments => []), "adding input");
ok(($event_loop eq 'anyevent' or $xpl->{_select}->exists(\*STDIN)),
   "input added to select");

ok($xpl->remove_input(\*STDIN), "removing input");
ok(($event_loop eq 'anyevent' or !$xpl->{_select}->exists(\*STDIN)),
   "input removed from select");

use_ok("xPL::Message");
my $msg = xPL::Message->new(message_type => 'xpl-stat',
                            head =>
                            {
                             source => "acme-clock.livingroom",
                            },
                            schema => "clock.update",
                            body =>
                            [
                             time => '20051113182650',
                            ],
                           );
undef $cb2;
$xpl->send($msg);
$xpl->main_loop(1);

is($xpl->xpl_callback_callback_count('hbeat'), 1, "callback counter");
is($xpl->xpl_callback_callback_count('hbeat2'), 2, "callback counter");
is($xpl->xpl_callback_callback_count('null'), 1, "callback counter self-skip");
ok($cb2 && exists $cb2->{message}, "message returned");
is($cb2->{message}->schema, 'clock.update', "correct message type");

undef $cb2;
$xpl->send($msg->string);
$xpl->main_loop(1);

is($xpl->xpl_callback_callback_count('hbeat'), 1, "callback counter");
is($xpl->xpl_callback_callback_count('hbeat2'), 3, "callback counter");
is($xpl->xpl_callback_callback_count('null'), 2, "callback counter self-skip");
ok($cb2 && exists $cb2->{message}, "message returned");
is($cb2->{message}->schema, 'clock.update', "correct message type");

undef $cb2;
$xpl->send(message_type => 'xpl-stat',
           head =>
           {
            source => "acme-clock.livingroom",
           },
           schema => "clock.update",
           body =>
           [
            time => '20051113182651',
           ]);
$xpl->main_loop(1);
is($xpl->xpl_callback_callback_count('hbeat'), 1, "callback counter");
is($xpl->xpl_callback_callback_count('hbeat2'), 4, "callback counter");
is($xpl->xpl_callback_callback_count('hbeat3'), 0, "callback counter");
is($xpl->xpl_callback_callback_count('hbeat4'), 0, "callback counter");
is($xpl->xpl_callback_callback_count('null'), 3, "callback counter self-skip");
ok($cb2 && exists $cb2->{message}, "message returned");
is($cb2->{message}->schema, 'clock.update', "correct message type");
is($cb2->{message}->field('time'), '20051113182651', "correct value");

undef $cb2;
$xpl->send(message_type => 'xpl-stat',
           head =>
            {
             source => "acme-clock.dingus",
            },
            schema => "hbeat.end",
            body =>
            [
             interval => 5,
             port => $xpl->listen_port,
             remote_ip => $xpl->ip,
            ],
           );
$xpl->main_loop(1);

is($xpl->xpl_callback_callback_count('hbeat'), 2, "callback counter");
is($xpl->xpl_callback_callback_count('hbeat2'), 5, "callback counter");
is($xpl->xpl_callback_callback_count('hbeat3'), 1, "callback counter");
is($xpl->xpl_callback_callback_count('hbeat4'), 1, "callback counter");
is($xpl->xpl_callback_callback_count('null'), 3, "callback counter self-skip");
ok($cb2 && exists $cb2->{message}, "message returned");
is($cb2->{message}->schema, 'hbeat.end', "correct message type");

ok($xpl->remove_xpl_callback('hbeat'), "remove xpl callback");

@h = $xpl->inputs();
is(scalar @h, 1, "inputs count");
my $handle = $h[0];
ok($xpl->remove_input($handle), "remove input");
@h = $xpl->inputs();
is(scalar @h, 0, "inputs count");

ok($xpl->add_input(handle => $handle), "add input with null callback");
ok(!defined $xpl->input_callback_time_average($handle),
   "input callback time average - undef");

$xpl->send(message_type => 'xpl-stat',
           head =>
            {
             source => "acme-clock.dingus",
            },
            schema => "hbeat.end",
            body =>
            [
             interval => 5,
             port => $xpl->listen_port,
             remote_ip => $xpl->ip,
            ],
           );
$xpl->main_loop(1);

is($xpl->input_callback_count($handle), 1, "input callback count");
ok(defined $xpl->input_callback_time_average($handle),
   "input callback time average");
ok($xpl->remove_input($handle), "remove input");

is(test_error(sub { $xpl->send(invalid => 'messagedata'); }),
   "MY::Listener->send_aux: message error: ".
     "xPL::ValidatedMessage->new: requires 'schema' parameter",
   "send with invalid message data");

check_stats(0,0,6);

is(test_error(sub {
    my $xpl = xPL::Listener->new(vendor_id => 'acme',
                                 device_id => 'dingus',
                                 ip => "not-ip",
                                 broadcast => "127.0.0.1",
                                );
  }),
   "xPL::Listener->new: ip invalid",
   "xPL::Listener invalid ip");

is(test_error(sub {
    my $xpl = xPL::Listener->new(vendor_id => 'acme',
                                 device_id => 'dingus',
                                 port => "not-port",
                                 ip => "127.0.0.1",
                                 broadcast => "127.0.0.1",
                                );
  }),
   "xPL::Listener->new: port invalid",
   "xPL::Listener invalid port");

is(test_error(sub {
    my $xpl = xPL::Listener->new(vendor_id => 'acme',
                                 device_id => 'dingus',
                                 ip => "127.0.0.1",
                                 broadcast => "not-broadcast",
                                );
  }),
   "xPL::Listener->new: broadcast invalid",
   "xPL::Listener invalid broadcast");

is(test_error(sub { $xpl->add_xpl_callback(); }),
   ref($xpl)."->add_xpl_callback: requires 'id' argument",
   "adding callback without an id");

is(test_error(sub { $xpl->add_xpl_callback(id => 'test',
                                          filter => ['invalid']); }),
   ref($xpl).'->add_xpl_callback: filter not scalar or hash',
   "adding callback with invalid filter");

is(test_warn(sub { $xpl->remove_xpl_callback('none'); }),
   ref($xpl)."->remove_xpl_callback: xpl_callback 'none' not registered",
   "removing non-existent callback");

is(test_warn(sub { $xpl->xpl_callback_callback_count('none'); }),
   ref($xpl)."->item_attrib: xpl_callback item 'none' not registered",
   "checking count of non-existent callback");

is(test_warn(sub { $xpl->remove_timer('none'); }),
   ref($xpl)."->_${event_loop}_remove_timer: timer 'none' not registered",
   "removing non-existent timer");

is(test_warn(sub { $xpl->timer_next('none'); }),
   ref($xpl)."->item_attrib: timer item 'none' not registered",
   "querying non-existent timer");

is(test_warn(sub { $xpl->timer_callback_count('none'); }),
   ref($xpl)."->item_attrib: timer item 'none' not registered",
   "querying non-existent timer tick count");

is(test_warn(sub { $xpl->remove_input('none'); }),
   ref($xpl)."->_${event_loop}_remove_input: input 'none' not registered",
   "removing non-existent input");

is(test_warn(sub { $xpl->dispatch_input('none'); }),
   ref($xpl)."->dispatch_input: input 'none' not registered",
   "dispatching non-existent input");

is(test_warn(sub { $xpl->input_callback_count('none'); }),
   ref($xpl)."->item_attrib: input item 'none' not registered",
   "checking attribute of non-existent input");

is(test_warn(sub { $xpl->dispatch_timer('none'); }),
   ref($xpl)."->dispatch_timer: timer 'none' not registered",
   "dispatching non-existent timer");

{
  package xPL::Test;
  use base 'xPL::Listener';
  sub port { $xpl->listen_port };
  1;
}

is(test_error(sub {
     my $test = xPL::Test->new(vendor_id => 'acme',
                               device_id => 'dingus',
                               ip => "127.0.0.1",
                               broadcast => "127.0.0.1");
  }),
   "xPL::Test->create_listen_socket: ".
     "Failed to bind listen socket: Address already in use",
   "bind failure");

SKIP: {
  skip "DateTime::Event::Cron", 5
    unless ($xpl->module_available("DateTime::Event::Cron"));
  ok($xpl->add_timer(id => 'every5m', timeout => 'cron crontab="*/5 * * * *"'),
     "cron based timer created");
  my $now = time;
  my $min = (localtime($now))[1];
  $min = ($min-($min%5)+5)%60;
  @t = $xpl->timers();
  is(scalar @t, 1, "timers count");
  my $tmin = (localtime($xpl->timer_next('every5m')))[1];
  is($tmin, $min, "cron based timer has correct minute value");
  $tmin = (localtime(&{$xpl->timer_attrib('every5m', 'next_fn')}($now)))[1];
  is($tmin, $min, "cron based timer next_fn has correct minute value");
  ok($xpl->remove_timer('every5m'), "remove timer 'every 5 minutes'");
}

# hack to ensure module isn't available to cause error
#$xpl->{_mod}->{"DateTime::Event::Cron"} = 0;
#is(test_warn(sub { $xpl->add_timer(id => 'every5m',
#                                   timeout => "C */5 * * * *"); }),
#   ref($xpl)."->add_timer: DateTime::Event::Cron modules is required
#in order to support crontab-like timer syntax",
#   "graceful crontab-like behaviour failure");

SKIP: {
  skip "Loopback doesn't support binding to 127.0.0.2 address", 1
    if ($^O eq 'darwin' || $^O eq 'freebsd');

  $xpl = $xpl->new(ip => "127.0.0.2",
                   broadcast => "127.0.0.1",
                  );
  ok($xpl, 'constructor from blessed reference - not recommended');
}

undef $xpl;

# mostly for coverage, these aren't used (yet)
like(test_warn(sub { xPL::Listener->ouch('ouch') }),
     qr/xPL::Listener->__ANON__(\[[^]]+\])?: ouch/,
     'warning message method on non-blessed reference');

like(test_error(sub { xPL::Listener->argh('argh'); }),
     qr/xPL::Listener->__ANON__(\[[^]]+\])?: argh/,
     'error message method on non-blessed reference');

is(test_warn(sub { xPL::Listener->ouch_named('eek', 'ouch') }),
   'xPL::Listener->eek: ouch',
   'warning message method on non-blessed reference');

is(test_error(sub { xPL::Listener->argh_named('ook', 'argh'); }),
   'xPL::Listener->ook: argh',
   'error message method on non-blessed reference');

sub check_stats {
  my ($timers, $inputs, $xpls) = @_;
  my $lines = test_output(sub { $xpl->dump_statistics }, \*STDERR);
  my @line = split /\n/, $lines;
  my $index = 0;
  is($line[$index++], "Timers", 'check_stats timer header');
  foreach (1..$timers) {
    like($line[$index++], qr/^[- ]\d+\.\d+ \w+/, 'check_stats timer '.$_);
  }
  is($line[$index++], "Inputs", 'check_stats inputs header');
  foreach (1..$inputs) {
    like($line[$index++], qr/^[- ]\d+\.\d+ \w+/, 'check_stats input '.$_);
  }
  is($line[$index++], "xPL Callbacks", 'check_stats xpl callbacks header');
  foreach (1..$xpls) {
    like($line[$index++], qr/^[- ]\d+\.\d+ \w+/,
         'check_stats xpl callback '.$_);
  }
  ok($index == scalar @line, 'check_stats eof');
}
