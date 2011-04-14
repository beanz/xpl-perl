package xPL::Client;

=head1 NAME

xPL::Client - Perl extension for an xPL Client

=head1 SYNOPSIS

  use xPL::Client;

  my $xpl = xPL::Client->new(id => 'acme-clock.default');
  $xpl->add_timer(name => 'tick',
                  timeout => 1,
                  callback => sub { $xpl->tick(@_) },
                  );

  $xpl->main_loop();

=head1 DESCRIPTION

This module creates an xPL client.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

my $HYPHEN = q{-};
my $DOT = q{.};

use POSIX qw/uname/;
use Time::HiRes;
use xPL::Listener;
use xPL::Config;

use Exporter;
#use AutoLoader qw(AUTOLOAD);

our @ISA = qw(xPL::Listener);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

my @attributes =
  qw/hbeat_mode vendor_id device_id
     hbeat_interval fast_hbeat_interval hopeful_hbeat_interval
     hub_response_timeout hbeat_count stealth/;
foreach my $a (@attributes) {
  __PACKAGE__->make_readonly_accessor($a);
}
__PACKAGE__->make_collection(event_callback => [qw/event
                                                   callback_count
                                                   callback_time_total
                                                   callback_time_max/]);

=head2 C<new(%params)>

The constructor creates a new xPL::Client object.  The constructor
takes a parameter hash as arguments.  Valid parameters in the hash
are:

=over 4

=item id

  The identity for this client.

=item interface

  The interface to use.  The default is to use the first active
  interface that isn't the loopback interface if there is one, or the
  loopback interface if that is the only one.  (Not yet implemented.)

=item ip

  The IP address to bind to.  This can be used instead of the
  'interface' parameter and will take precedent over the 'interface'
  parameter if they are in conflict.

=item broadcast

  The broadcast address to use.  This is required if the 'ip'
  parameter has been given.

=back

It returns a blessed reference when successful or undef otherwise.

=cut

sub new {
  my $pkg = shift;
  if (ref $pkg) { $pkg = ref $pkg }

  my %p = @_;
  push @_, hubless => 1 if (exists $p{stealth});
  my $self = $pkg->SUPER::new(@_);
  $self->{_hbeat_count} = 0;

  foreach (qw/vendor_id device_id/) {
    exists $p{$_} or $self->argh("requires '$_' parameter");
    $p{$_} =~ /^[A-Za-z0-9]{1,8}$/ or $self->argh("$_ invalid");
  }

  exists $p{instance_id} or
    $p{instance_id} = substr $ENV{XPL_HOSTNAME}||(uname)[1]||'default', 0, 16;
  $p{instance_id} =~ s/\..*$//; # strip domain if there is one
  $p{instance_id}=~/^[A-Za-z0-9]{1,16}$/ or
    $self->argh('instance_id, '.$p{instance_id}.", is invalid.\n".
      "The default can be overridden by setting the XPL_HOSTNAME environment\n".
      'variable');

  foreach ([hbeat_interval => 5, 5, 30, 'minutes'],
           [fast_hbeat_interval => 3, 3, 30, 'seconds'],
           [hopeful_hbeat_interval => 30, 20, 300, 'seconds'],
           [hub_response_timeout => 120, 30, 300, 'seconds']) {
    validate_param(\%p, @$_) or
      $self->argh(sprintf '%s is invalid: should be %d - %d (%s)',
                  (@$_)[0,2,3,4]);
  }

  foreach (qw/vendor_id device_id instance_id
              hbeat_interval fast_hbeat_interval
              hopeful_hbeat_interval hub_response_timeout
              stealth/) {
    $self->{'_'.$_} = $p{$_};
  }

  $self->{_max_fast_hbeat_count} =
    int $self->hub_response_timeout / $self->fast_hbeat_interval;

  $self->init_event_callbacks();

  my $needs_config = $self->init_config(\%p);
  my $class = $needs_config ? 'config' : 'hbeat';
  $self->{_hbeat_class} = $class;

  if ($self->stealth) {
    $self->argh("Can't use stealth mode until config is complete\n")
      if ($class eq 'config');
    return $self;
  }

  my %xpl_message_args =
    (
     message_type => 'xpl-stat',
     head => { source => $self->id },
     body => [ interval => $self->hbeat_interval ],
    );
  if ($self->hubless) {
    $self->standard_hbeat_mode(1);
    $xpl_message_args{schema} = $class.'.basic';
    $self->add_xpl_callback(id => '!hub-found',
                            self_skip => 0,
                            filter =>
                            {
                             schema => $self->{_hbeat_class}.'.basic',
                             source => $self->id,
                            },
                            callback => sub {
                              $self->call_event_callbacks('hub_found');
                              $self->remove_xpl_callback('!hub-found');
                              0;
                            });

  } else {
    $self->fast_hbeat_mode();
    $xpl_message_args{schema} = $class.'.app';
    push @{$xpl_message_args{body}}, port => $self->listen_port;
    push @{$xpl_message_args{body}}, remote_ip => $self->ip;
  }

  $self->{_hbeat_message} = xPL::Message->new(%xpl_message_args);

  $self->add_xpl_callback(id => '!hbeat-request',
                          self_skip => 0,
                          filter =>
                          {
                           message_type => 'xpl-cmnd',
                           schema => 'hbeat.request',
                          },
                          callback => sub { $self->hbeat_request(@_) });

  if ($self->has_config()) {
    $self->add_xpl_callback(id => '!config-list',
                            filter =>
                            {
                             message_type => 'xpl-cmnd',
                             schema => 'config.list',
                            },
                            callback => sub { $self->config_list(@_) });
    $self->add_xpl_callback(id => '!config-current',
                            filter =>
                            {
                             message_type => 'xpl-cmnd',
                             schema => 'config.current',
                            },
                            callback => sub { $self->config_current(@_) });
    $self->add_xpl_callback(id => '!config-response',
                            filter =>
                            {
                             message_type => 'xpl-cmnd',
                             schema => 'config.response',
                            },
                            callback => sub { $self->config_response(@_) });
  }

  $self->add_xpl_callback(id => '!ping-request',
                          self_skip => 0,
                          filter =>
                          {
                           message_type => 'xpl-cmnd',
                           schema => 'ping.request',
                          },
                          callback => sub { $self->ping_request(@_) });

  return $self;
}

=head2 C<init_config( $params )>

This method creates a new L<xPL::Config> object for the client if
a configuration specification is found for the C<vendor_id-device_id>
client.

=cut

sub init_config {
  my $self = shift;
  $self->{_config} =
    xPL::Config->new(key => $self->vendor_id.'-'.$self->device_id,
                     instance => $self->instance_id);
  return $self->needs_config();
}

=head2 C<has_config()>

This method returns true if this client is configurable with the standard
C<config.*> xPL messages.

=cut

sub has_config {
  my $self = shift;
  return defined $self->{_config};
}

=head2 C<needs_config()>

This method returns true if this client is configurable with the standard
C<config.*> xPL messages and it has configuration items that are currently
unconfigured.

=cut

sub needs_config {
  my $self = shift;
  return unless (defined $self->{_config});
  my @needs = $self->{_config}->items_requiring_config();
  $self->info("Config needed? = @needs\n") if (@needs);
  return scalar @needs;
}

=head2 C<config_list()>

This method sends a response to an incoming C<config.list> request.

=cut

sub config_list {
  my $self = shift;
  my $body = $self->{_config}->config_types;
  my @body = ();
  foreach (qw/config reconf option/) {
    push @body, $_ => $body->{$_} if (exists $body->{$_});
  }
  $self->send(message_type => 'xpl-stat',
              schema => 'config.list',
              body => \@body);
  return 1
}

=head2 C<config_current()>

This method sends a response to an incoming C<config.current> request.

=cut

sub config_current {
  my $self = shift;
  my @body = ();
  foreach ($self->{_config}->items) {
    my $v = $self->{_config}->get_item($_) || '';
    push @body, $_ => $v;
  }
  $self->send(message_type => 'xpl-stat',
              schema => 'config.current',
              body => \@body);
  return 1
}

=head2 C<config_response()>

This method processes the incoming C<config.response> messages to update
the configuration of the client.  If a value is changed then the
C<config_E<lt>item_nameE<gt>> event callback is called.  If any value
is changed then the C<config_changed> event callback is invoked.

=cut

sub config_response {
  my $self = shift;
  my %p = @_;
  my $msg = $p{message};
  my @changed;
  foreach my $name (sort $msg->body_fields()) {
    next unless ($self->{_config}->is_item($name));
    my $old = $self->{_config}->get_item($name);
    my $new = $msg->field($name);
    my $event = $self->{_config}->update_item($name, $new);
    if ($event) {
      # print STDERR
      #   "E: $name $event to ", (ref $new ? (join ', ', @$new) : $new), " \n";
      push @changed, { name => $name,
                       old => $old,
                       new => $new,
                       type => $event,
                     };
      $self->call_event_callbacks('config_'.$name,
                                  type => $event,
                                  old => $old,
                                  new => $new,
                                 );
    }
  }
  $self->call_event_callbacks('config_changed', changes => \@changed)
    if (@changed);
  return 1
}

=head2 C<hbeat_mode()>

Returns the current hbeat mode for this client.  Possible values
are:

=over

=item fast

  During the initial interval when hbeats are sent quickly.

=item hopeful

  When the hub has failed to respond to the initial fast hbeats
  and hbeats are being sent at a moderate rate in the hope that
  the hub might appear.

=item standard

  When the hub has responded and hbeats are being sent at the
  standard interval.

=item undef

  When we've sent the hub a C<hbeat.end> message.

=back

=head2 C<id()>

Returns the identity for this source.

=cut

sub id {
  my $self = shift;
  $self->ouch('called with an argument, but id is readonly') if (@_);
  return
    $self->{_vendor_id}.$HYPHEN.$self->{_device_id}.$DOT.$self->{_instance_id};
}

=head2 C<vendor_id()>

Returns the vendor ID for this source.

=head2 C<device_id()>

Returns the device ID for this source.

=head2 C<instance_id()>

Returns the instance ID for this source.

=cut

sub instance_id {
  my $self = shift;
  if (@_) {
    my $id = $_[0];
    $self->ouch("invalid instance_id '$id'")
      unless ($id =~ qr/^[A-Za-z0-9]{1,12}$/);
    $self->{_instance_id} = substr $_[0], 0, 12;
  }
  return $self->{_instance_id};
}

=head2 C<hbeat_interval()>

Returns the hbeat interval (in minutes) for this source.

=head2 C<fast_hbeat_interval()>

Returns the fast/initial hbeat interval (in seconds) for this source.

=head2 C<hopeful_hbeat_interval()>

Returns the hopeful hbeat interval (in seconds) for this source.
This is used if the hub fails to respond to the initial fast hbeat
messages.

=head2 C<hub_response_timeout()>

Returns the hub response timeout (in seconds) for this source.  This
is the amount of time that fast hbeat messages are sent before the
client backs off and sends hbeat messages at the slower hopeful hbeat
interval.

=head2 C<fast_hbeat_mode()>

This method puts the client into the fast hbeat mode - typically when
the client is initially started up.

=cut

sub fast_hbeat_mode {
  my $self = shift;

  $self->{_hbeat_mode} = 'fast';

  $self->add_timer(id => '!fast-hbeat',
                   # negative so it's triggered ASAP
                   timeout => -$self->fast_hbeat_interval(),
                   callback => sub { $self->fast_hbeat(); },
                  );

  $self->add_xpl_callback(id => '!hub-found',
                          self_skip => 0,
                          filter =>
                          {
                           schema => $self->{_hbeat_class}.'.app',
                           source => $self->id,
                          },
                          callback => sub { $self->hub_response(@_) });
  return 1;
}

=head2 C<standard_hbeat_mode()>

This method puts the client into the standard hbeat mode - typically after
the client has received a response from the hub.

=cut

sub standard_hbeat_mode {
  my $self = shift;
  my $immediate = shift;

  my $timeout = $self->hbeat_interval*60;
  $timeout *= -1 if ($immediate);
  $self->{_hbeat_mode} = 'standard';
  $self->add_timer(id => '!hbeat',
                   timeout => $timeout,
                   callback => sub { $self->send_hbeat(@_) },
                  );
  return 1;
}

=head2 C<fast_hbeat()>

This method is the callback that sends the hbeats when the
client is in fast and hopeful mode.  It is also responsible
for reducing the frequency of the hbeat messages if the
hub fails to respond.

=cut

sub fast_hbeat {
  my $self = shift;
  $self->send_hbeat();
  if ($self->{_hbeat_count} == $self->{_max_fast_hbeat_count}) {
    $self->{_hbeat_mode} = 'hopeful';
    $self->remove_timer('!fast-hbeat');
    $self->add_timer(id => '!fast-hbeat',
                     timeout => $self->hopeful_hbeat_interval,
                     callback => sub {
                       $self->send_hbeat();
                     });
  }
  return 1;
}

=head2 C<hub_response()>

This method is the callback is used to check for a response from the
local hub.  If it sees the hub response, it removes itself and the
fast (or hopeful) hbeat timer from the main loop and adds the
standard rate hbeat timer.

=cut

sub hub_response {
  my $self = shift;

  # we have a winner, our hbeat has been returned
  $self->remove_timer('!fast-hbeat');
  $self->remove_xpl_callback('!hub-found');

  $self->standard_hbeat_mode();

  $self->call_event_callbacks('hub_found');

  return 1;
}

=head2 C<hbeat_request()>

This method is the callback is used to handle C<hbeat.request> messages.

=cut

sub hbeat_request {
  my $self = shift;

  $self->add_timer(id => '!hbeat-response',
                   timeout => 2 + rand 4,
                   callback => sub { $self->send_extra_hbeat(@_); 1; },
                  );
  return 1;
}

=head2 C<ping_request()>

This method is the callback is used to handle C<ping.request> messages.

=cut

sub ping_request {
  my $self = shift;

  if ($self->exists_timer('!ping-response')) {
    # we are about to respond anyway so do nothing
    return 1;
  }
  $self->ping_check();
  my $delay = 2 + rand 4;
  $self->add_timer(id => '!ping-response',
                   timeout => $delay,
                   callback =>
                     sub { $self->send_ping_response($delay, @_); return 0; },
                  );
  return 1;
}

=head2 C<ping_action()>

This method is intended to confirm that the client is functioning
correctly.  The default implementation simply calls L<ping_done> with
the string argument, 'ok'.  It is intended to be overridden by clients
to provide more substantial functionality to confirm (or not) that the
client is really functioning correctly.  It is intended that the
checking is asynchronous so strictly-speaking this method should begin
the checking process.

=cut

sub ping_action {
  my $self = shift;
  $self->ping_done('ok');
}

=head2 C<ping_kill_action()>

This method is intended to be overridden by clients and should terminate
any checking process that has been started.  It is called by the method
that sends the ping response if the check is not finished sufficiently
quickly.

=cut

sub ping_kill_action {
  my $self = shift;
  # nothing to kill
  return 1;
}

=head2 C<ping_check()>

This method is the used to perform any checks needed to confirm that the
client is functioning correctly.  It calls L<ping_start> to record the
time and then calls L<ping_action>.

=cut

sub ping_check {
  my $self = shift;
  $self->ping_start();
  $self->ping_action();
  return 1;
}

=head2 C<ping_start()>

This method is the used to record the start time of the ping checking.

=cut

sub ping_start {
  my $self = shift;
  $self->{ping} =
    {
     start => Time::HiRes::time,
    };
  return 1;
}

=head2 C<ping_done()>

This method is the used to record the end time and status of the ping
checking.  The default status is 'ok'.

=cut

sub ping_done {
  my $self = shift;
  $self->{ping}->{state} = shift || 'ok';
  my $end = $self->{ping}->{end} = Time::HiRes::time;
  $self->{ping}->{time} = $end - $self->{ping}->{start};
  return 1;
}

=head2 C<send_ping_response()>

This method is the used to determine if the ping checking actions have
succeeded and to send the response.  Or if the ping checking is still
running to terminate it and send a C<ping.response> with state
'timeout'.

=cut

sub send_ping_response {
  my $self = shift;
  my $delay = shift;
  my @body =
    (
     delay => $delay,
     state => $self->{ping}->{state} || 'timeout',
    );
  push @body, checktime => $self->{ping}->{time}
    if (exists $self->{ping}->{time});
  $self->send(message_type => 'xpl-stat',
              schema => 'ping.response', body => \@body);
  return 1;
}

=head1 COMMON MESSAGE METHODS

=head2 C<send_extra_hbeat()>

This method is called when the client wants to send an extra heartbeat
message.  For example, it is used to respond to a C<hbeat.request>
message.

=cut

sub send_extra_hbeat {
  my $self = shift;
  $self->send_hbeat(@_);
  $self->reset_timer('!hbeat') if ($self->exists_timer('!hbeat'));
  return 1;
}

=head2 C<send_hbeat()>

This method is called periodically to send hbeat messages.

=cut

sub send_hbeat {
  my $self = shift;
  $self->{_hbeat_count}++;
  $self->send($self->{_hbeat_message});
  # if we are due to respond to a request but we've sent a message anyway
  # make sure we don't send another one
  $self->remove_timer('!hbeat-response')
    if ($self->exists_timer('!hbeat-response'));
  return 1;
}

=head2 C<send_hbeat_end()>

This method is called to send a dying hbeat message.

=cut

sub send_hbeat_end {
  my $self = shift;
  return unless (defined $self->{_hbeat_mode});
  undef $self->{_hbeat_mode};
  $self->send(message_type => 'xpl-stat',
              schema => $self->{_hbeat_class}.'.end',
              body =>
              [
               interval => $self->hbeat_interval,
               port => $self->listen_port,
               remote_ip => $self->ip,
              ],
             );
  return 1;
}

=head2 C<send_sensor_basic($device, $type, $value, [$units])>

This method is called to send an C<xpl-stat> or C<xpl-trig>
C<sensor.basic> message depending on whether the C<current>
value has changed since the previously sent value.

=cut

sub send_sensor_basic {
  my ($self, $device, $type, $value, $units) = @_;
  my $key = $device.'-'.$type;
  my $old = $self->{_sensor_state}->{$key};
  $self->{_sensor_state}->{$key} = $value;
  my $msg_type;
  my $output;
  if (!defined $old || $value ne $old) {
    $msg_type = 'xpl-trig';
    $output = 1;
  } else {
    $msg_type = 'xpl-stat';
  }
  my @body =
    (
     device => $device,
     type => $type,
     current => $value,
    );
  push @body, units => $units if (defined $units);
  my $msg = $self->send(message_type => $msg_type,
                        schema => 'sensor.basic',
                        body => \@body);
  $self->info($msg->body_summary, "\n") if ($output);
  return $msg;
}

=head2 C<exiting( )>

This method is called when we are exiting.

=cut

sub exiting {
  my ($self) = @_;
  $self->send_hbeat_end();
  return $self->SUPER::exiting();
}

=head2 C<<add_event_callback(id => 'id', event => 'name', callback => sub {}, ...)>>

This method adds a callback for the named event.  Currently the only
event provided is the 'hub_found' event.  The unique identifier is
used to distinguish multiple callbacks registered for the same event.

=cut

sub add_event_callback {
  my $self = shift;
  my %p = @_;
  exists $p{id} or $self->argh("requires 'id' argument");
  exists $p{event} or $self->argh("requires 'event' argument");
  my $res = $self->add_callback_item('event_callback', $p{id}, \%p);
  $self->{_event}->{$p{event}}->{$p{id}}++;
  return $res;
}

=head2 C<remove_event_callback( $id )>

This method removes the event callback with the given id.

=cut

sub remove_event_callback {
  my ($self, $name) = @_;
  my $event = $self->event_callback_event($name);
  delete $self->{_event}->{$event}->{$name};
  return $self->remove_item('event_callback', $name);
}

=head2 C<call_event_callbacks( $event )>

This method calls the registered callbacks for the given event (if any
are registered).

=cut

sub call_event_callbacks {
  my $self = shift;
  my $event = shift;
  my $count;
  foreach my $id (sort keys %{$self->{_event}->{$event}}) {
    $self->call_callback('event_callback', $id, event => $event, @_);
    $count++;
  }
  return $count;
}

=head2 C<validate_param($params, $name, $default, $min, $max)>

This method is a helper method used by the constructor to check the
validity of integer arguments against a range and applies the default
value if it is not provided.

=cut

sub validate_param {
  my ($params, $name, $default, $min, $max) = @_;
  exists $params->{$name} or return $params->{$name} = $default;
  ($params->{$name} =~ /^\d+$/ &&
   $params->{$name} >= $min && $params->{$name} <= $max);
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2005, 2010 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
