#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use Socket;
use Test::More tests => 26;
use File::Temp qw/tempdir/;
use t::Helpers qw/test_error test_warn test_output/;

my $dir = tempdir(CLEANUP => 1);
$ENV{XPL_CONFIG_PATH} = $dir;
push @INC, 't/config';
$ENV{XPL_HOSTNAME} = 'mytestid';

use_ok('xPL::Client');

my @msg;
sub xPL::Client::send_aux {
  my $self = shift;
  my $sin = shift;
  push @msg, [@_];
}

my $xpl = xPL::Client->new(vendor_id => 'acme', device_id => 'config',
                           instance_id => 'test', ip => "127.0.0.1",
                           broadcast => "127.255.255.255",
                           port => 0,
                          );
ok($xpl, 'constructor');
ok($xpl->has_config(), 'has_config()');
is($xpl->needs_config(), 2, 'needs_config()');


my $msg =
  xPL::Message->new(message_type => 'xpl-cmnd',
                    head => { source => 'acme-config.tester' },
                    class => 'config.list',
                    body => [ command => 'request' ]);
$xpl->dispatch_xpl_message($msg);

is(xPL::Message->new(@{$msg[0]},
                     head => { source => 'test-test.test' })->string,
   'xpl-stat
{
hop=1
source=test-test.test
target=*
}
config.list
{
reconf=username
reconf=password
option=newconf
option=resource
option=host
option=port
option=friend[32]
}
', 'config.list response');

$msg =
  xPL::Message->new(message_type => 'xpl-cmnd',
                    head => { source => 'acme-config.tester' },
                    class => 'config.response',
                    body =>
                    [
                     newconf => 'foo',
                     username => 'user',
                     password => 'pass',
                     bar => 'baz', # should be ignored
                    ]);

my @args = ();
$xpl->add_event_callback(id => 'config_changed_cb', event => 'config_changed',
                         callback => sub { push @args, \@_ });

$xpl->add_event_callback(id => 'config_newconf_cb', event => 'config_newconf',
                         callback => sub { push @args, \@_ });
$xpl->add_event_callback(id => 'config_username_cb', event => 'config_username',
                         callback => sub { push @args, \@_ });

$xpl->dispatch_xpl_message($msg);

is($xpl->needs_config(), 0, 'needs_config() - all set');

is(scalar @args, 3, 'changes invoked 3 callbacks');
my %p = @{$args[0]};
is($p{id}, 'config_newconf_cb', 'newconf - id');
is($p{new}, 'foo', 'newconf - new value');
is($p{old}, undef, 'newconf - old value');
is($p{type}, 'set', 'newconf - type');

%p = @{$args[1]};
is($p{id}, 'config_username_cb', 'username - id');
is($p{new}, 'user', 'username - new value');
is($p{old}, undef, 'username - old value');
is($p{type}, 'set', 'username - type');

%p = @{$args[2]};
is($p{id}, 'config_changed_cb', 'config_changed - id');
is_deeply($p{changes},
  [
   { name => 'newconf', new => 'foo', old => undef, type => 'set' },
   { name => 'password', new => 'pass', old => undef, type => 'set' },
   { name => 'username', new => 'user', old => undef, type => 'set' },
  ], 'config_changed - changes');

@args = ();
$xpl->dispatch_xpl_message($msg);
is(scalar @args, 0, 'no changes so no callbacks');

@args = ();
$xpl->remove_event_callback('config_changed_cb');
$msg =
  xPL::Message->new(message_type => 'xpl-cmnd',
                    head => { source => 'acme-config.tester' },
                    class => 'config.response',
                    body =>
                    [
                     newconf => 'foo',
                     username => 'bar',
                     password => 'pass',
                     bar => 'baz', # should be ignored
                    ]);
$xpl->dispatch_xpl_message($msg);
is(scalar @args, 1, 'changes involved one callback');
%p = @{$args[0]};
is($p{id}, 'config_username_cb', 'username - id');
is($p{new}, 'bar', 'username - new value');
is($p{old}, 'user', 'username - old value');
is($p{type}, 'changed', 'username - type');

$msg =
  xPL::Message->new(message_type => 'xpl-cmnd',
                    head => { source => 'acme-config.tester' },
                    class => 'config.current',
                    body => [ command => 'request' ]);
@msg = ();
$xpl->dispatch_xpl_message($msg);

is(xPL::Message->new(@{$msg[0]},
                     head => { source => 'test-test.test' })->string,
   'xpl-stat
{
hop=1
source=test-test.test
target=*
}
config.current
{
newconf=foo
username=bar
password=pass
resource=
host=
port=
friend=
}
', 'config.current response');

is(test_error(sub { $xpl->add_event_callback() }),
   q{xPL::Client->add_event_callback: requires 'id' argument},
   'add_event_callback - id error');
is(test_error(sub { $xpl->add_event_callback(id => 1) }),
   q{xPL::Client->add_event_callback: requires 'event' argument},
   'add_event_callback - event error');
