package xPL::Listener;

=head1 NAME

xPL::Listener - Perl extension for an xPL Listener

=head1 SYNOPSIS

  use xPL::Listener;

  my $xpl = xPL::Listener->new(ip => $ip, broadcast => $broadcast) or
      die "Failed to create xPL::Client\n";

  $xpl->add_timer(id => 'tick',
                  timeout => 1,
                  callback => sub { $xpl->tick(@_) },
                 );

  $xpl->main_loop();

=head1 DESCRIPTION

This is a module for creating xPL listeners.  Typically, the
subclasses xPL::Client and xPL::Hub would be used rather than this
module.  It provides a main loop and allows callbacks to be registered
for events that occur.

The listener does not fork.  Therefore all callbacks must either be
short or they should fork.  For example, a callback that needed to
make an HTTP request could connect and send the request then add the
socket handle to receive the response to the listener event loop with a
suitable callback to handle the reply.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;

use IO::Select;
use List::Util qw/min/;
use Socket;
use Time::HiRes;

use xPL::Message;
use xPL::Timer;

use xPL::Base qw/simple_tokenizer/;
#use AutoLoader qw(AUTOLOAD);

our @ISA = qw(xPL::Base);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

__PACKAGE__->make_collection(input => [qw/handle arguments callback
                                          callback_count anyevent
                                          callback_time_total
                                          callback_time_max/],
                             timer => [qw/next timeout
                                          timer next_fn count anyevent
                                          arguments callback
                                          callback_count
                                          callback_time_total
                                          callback_time_max/],
                             xpl_callback => [qw/filter
                                                 self_skip targeted
                                                 arguments callback
                                                 callback_count
                                                 callback_time_total
                                                 callback_time_max/],
                            );
__PACKAGE__->make_readonly_accessor(qw/ip broadcast interface
                                       listen_port port hubless
                                       last_sent_message/);

our $EVENT_LOOP = (defined $AnyEvent::VERSION ? 'anyevent' : 'default');
{
  my $prefix = __PACKAGE__.'::_'.$EVENT_LOOP.'_';
  no strict qw/refs/; ## no critic
  foreach my $method (qw/main_loop time_now
                         add_input remove_input
                         timer_next remove_timer/) {
    *{__PACKAGE__.'::'.$method} = *{$prefix.$method};
  }
  use strict qw/refs/;
}

=head2 C<new(%params)>

The constructor creates a new xPL::Listener object.  The constructor
takes a parameter hash as arguments.  Valid parameters in the hash
are:

=over 4

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

=item port

  The port for xPL broadcast messages to use.  This is required if the
  'ip' parameter has been given.

=back

It returns a blessed reference when successful or undef otherwise.

=cut

sub new {
  my $pkg = shift;
  $pkg = ref($pkg) if (ref($pkg));

  my $self = {};
  bless $self, $pkg;

  my %p = @_;
  $self->{_verbose} = $p{verbose} || 0;
  $self->{_hubless} = $p{hubless} || 0;
  $self->{_xpl_filter_tree} = {};

  if (exists $p{port}) {
    $p{port} =~ /^(\d+)$/ or $self->argh('port invalid');
    $self->{_port} = $p{port};
  } else {
    $self->{_port} = 0;
  }

  unless (exists $p{ip} && exists $p{broadcast}) {

    if (exists $p{interface}) {
      $self->{_interface_info} = $self->interface_info($p{interface}) or
        $self->argh("Unable to detect interface ".$p{interface});
    } else {
      $self->{_interface_info} =
        $self->default_interface_info() || $self->interface_info('lo');
    }

    if ($self->{_interface_info}) {
      $self->{_interface} = $self->{_interface_info}->{device};
      $self->{_ip} = $self->{_interface_info}->{ip};
      $self->{_broadcast} = $self->{_interface_info}->{broadcast};
    }
  }

  foreach (qw/ip broadcast/) {
    next unless (exists $p{$_});
    $p{$_} =~ /^(\d+\.){3}\d+$/ or $self->argh("$_ invalid");
    $self->{'_'.$_} = $p{$_};
  }

  unless ($self->{_broadcast}) {
    $self->argh("Unable to determine broadcast address.\n".
                'An interface or broadcast address should be specified.');
  }
  unless ($self->{_ip}) {
    $self->argh("Unable to determine ip address.\n".
                'An interface or ip address should be specified.');
  }

  $self->init_timers();
  $self->init_inputs();
  $self->init_xpl_callbacks();

  $self->{_is_initialized} = 1;

  undef $self->{_select};

  $self->create_listen_socket();
  $self->create_send_socket();

  return $self;
}

sub DESTROY {
  $_[0]->cleanup;
  close $_[0]->{_listen_sock} if (defined $_[0]->{_listen_sock});
  close $_[0]->{_send_sock} if (defined $_[0]->{_send_sock});
}

=head1 ATTRIBUTE METHODS

=head2 C<ip()>

Returns the IP address of this source.

=head2 C<broadcast()>

Returns the broadcast address for this source.

=head2 C<port()>

Returns the port that this client will try to listen on.  This is distinct
from L<listen_port> in that it might be 0 and L<listen_port> would be the
port that was allocated by the OS at bind time.

=head2 C<listen_port()>

Returns the listen port for this source.

=head2 C<listen_addr()>

Returns the listen port for this source.

=cut

sub listen_addr {
  my $self = shift;
  $self->ouch('called with an argument, but listen_addr is readonly') if (@_);
  return $self->ip;
}

=head1 SOCKET METHODS

=head2 C<create_listen_socket()>

This method creates the socket to listen for incoming messages.

=cut

sub create_listen_socket {
  my $self = shift;

  my $listen;
  socket($listen, PF_INET, SOCK_DGRAM, getprotobyname('udp'));
  setsockopt $listen, SOL_SOCKET, SO_BROADCAST, 1;
  if ($self->{_hubless}) {
    setsockopt $listen, SOL_SOCKET, SO_REUSEADDR, 1 or do {
      warn "Setting SO_REUSEADDR failed ... switching off hubless mode.\n";
      $self->{_hubless} = 0;
    };
  }
  binmode $listen;

 RETRY:
  my $ip = $self->{_hubless} ? $self->{_broadcast} : $self->listen_addr();
  my $port = $self->port || ($self->{_hubless} ? 3865 : 0);
  unless (bind($listen, sockaddr_in($port, inet_aton($ip)))) {
    if ($self->{_hubless}) {
      warn "bind failed ... switching off hubless mode.\n";
      $self->{_hubless} = 0;
      goto RETRY;
    }
    $self->argh("Failed to bind listen socket: $!\n");
  }

  $self->{_listen_sock} = $listen;
  my $addr;
  ($self->{_listen_port}, $addr) = sockaddr_in(getsockname($listen));
  $self->{_listen_addr} = inet_ntoa($addr);
  $self->info('Listening on ',
              $self->{_listen_addr}, ':', $self->{_listen_port}, "\n");

  $self->add_input(handle => $listen,
                   callback => sub { $self->xpl_message(@_) });

  return $listen;
}

=head2 C<create_send_socket()>

This method creates the socket used to send outgoing messages.

=cut

sub create_send_socket {
  my $self = shift;
  my $send;
  if ($self->{_hubless}) {
    $send = $self->{_listen_sock};
  } else {
    socket($send, PF_INET, SOCK_DGRAM, getprotobyname('udp'));
    setsockopt $send, SOL_SOCKET, SO_BROADCAST, 1;
    binmode $send;
  }
  $self->{_send_sock} = $send;
  $self->{_send_sin} = sockaddr_in(3865, inet_aton($self->{_broadcast}));
  $self->info('Sending on ', $self->{_broadcast}, "\n");
  return 1;
}

=head2 C<send_aux($sin, $msg | %params )>

This method sends a message using the given C<sockaddr_in> structure.
The L<xPL::Message> is either passed directly or constructed from the
given parameters.  The advantage of passing parameters is that the
C<source> value will be filled in for objects for which it is defined.
It returns the message sent if successful or undef otherwise.

=cut

sub send_aux {
  my $self = shift;
  my $sin = shift;
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
  $self->_send_aux_string($sin, ref $msg ? $msg->string : $msg) and $msg;
}

sub _send_aux_string {
  my ($self, $sin, $str) = @_;
  $self->{_last_sent_message} = $str;
  my $sock = $self->{_send_sock};
  send($sock, $str, 0, $sin);
}

=head2 C<send( $msg | %params )>

This method sends a message using the default sending socket.  The
L<xPL::Message> is either passed directly or constructed from the
given parameters.  The advantage of passing parameters is that the
C<source> value will be filled in for objects for which it is defined.

=cut

sub send {
  my $self = shift;
  my $sin = $self->{_send_sin};
  return $self->send_aux($sin, @_);
}

=head2 C<send_from_string( $simple_string )>

This method takes a simple string representing details of a message
and tries to send an xPL message from using a message constructed
from those details.  For instance, the string:

  -m xpl-cmnd -c x10.basic command=on device=e3

would try create and 'xpl-cmnd'-type message with a schema/class of
'x10.basic' with 'command' set to 'on' and 'device' set to 'e3' in the
body.  It tries to correctly handle balanced quotes such as:

  -m xpl-cmnd -c osd.basic command=write text="This is a 'test'!"

and even:

  -m xpl-cmnd -c osd.basic command=write text="This is a \"test\"!"

It is intended to be used to construct messages from simple string
based input sources such as instant messages.

=cut

sub send_from_string {
  my $self = shift;
  my $simple_string = shift;
  my @t = simple_tokenizer($simple_string);
  return $self->send_from_list(@t);
}

=head2 C<send_from_arg_list( @argv_style_list )>

This method takes a list representing details of a message
and tries to send an xPL message from using a message constructed
from those details.  For instance, the list:

  '-m', 'xpl-cmnd', '-c','x10.basic', 'command=on', 'device=e3'

would try create and 'xpl-cmnd'-type message with a schema/class of
'x10.basic' with 'command' set to 'on' and 'device' set to 'e3' in the
body.  It is intended to be used to construct messages from lists
such as C<@ARGV>.

=cut

sub send_from_arg_list {
  my $self = shift;
  my @t =  map { split /=/, $_, 2 } @_;
  return $self->send_from_list(@t);
}

=head2 C<send_from_list( @list_of_tokens )>

This method takes a simple list representing details of a message
and tries to send an xPL message from using a message constructed
from those details.  For instance, the list of the form:

  '-m', 'xpl-cmnd', '-c', 'x10.basic', 'command', 'on', 'device', 'e3'

would try create and 'xpl-cmnd'-type message with a schema/class of
'x10.basic' with 'command=on' and 'device=e3' in the body.

This method is used by L<send_from_string()> and
L<send_from_arg_list()>.

=cut

sub send_from_list {
  my $self = shift;
  my @body;
  my %args;
  my $i = 0;
  while ($i <= $#_) {
    my $k = $_[$i++];
    my $v = $_[$i++];
    if ($k eq '-m' || $k eq 'message_type') {
      $args{message_type} = $v;
    } elsif ($k eq '-c' || $k eq 'schema') {
      $args{schema} = $v;
    } elsif ($k eq '-s' || $k eq 'source') {
      $args{head}->{source} = $v;
    } elsif ($k eq '-t' || $k eq 'target') {
      $args{head}->{target} = $v;
    } elsif ($k eq 'validate') {
      $args{$k} = $v;
    } else {
      push @body, $k => $v;
    }
  }
  return $self->send(%args, body => \@body);
}

=head1 MESSAGE CALLBACK METHODS

=head2 C<add_xpl_callback(%params)>

This method defines a callback that should receive xPL messages.
This method takes a parameter hash as arguments.  Valid parameters in
the hash are:

=over 4

=item id

  A unique id for this message callback - used to identify the
  callback, for instance to remove it.  This parameter is required.

=item callback

  A code reference to be executed with incoming xPL messages.
  The default is the empty code reference.

=item arguments

  An array reference of arguments to be passed to the callback.  The
  default is the empty array reference.

=item filter

  A hash reference containing keys matching xPL::Message methods with
  values that are regular expressions to match against the message
  attribute.  For example, the following will match C<x10.basic>
  trigger messages.

    {
     message_type => 'xpl-trig',
     schema => 'x10.basic',
    }

  It is also possible, though not advisable in normal Perl code, to
  provide a filter as a string that is parsed using
  L<simple_tokenizer> to produce a hash like the reference described
  above.  This syntax is intended to be used where the natural source
  format is a string - such as when the filter is obtained from a
  database.

=back

=cut

sub add_xpl_callback {
  my $self = shift;
  my %p = @_;
  exists $p{id} or $self->argh("requires 'id' argument");
  exists $p{self_skip} or $p{self_skip} = 1;
  if (exists $p{targetted}) {
    $p{targeted} = $p{targetted};
    delete $p{targetted};
    warnings::warnif('deprecated',
                     '"targetted" is deprecated. Use "targeted" instead.');
  }
  exists $p{targeted} or $p{targeted} = 1;
  if (exists $p{filter}) {
    my $filter = $p{filter};
    if (ref($filter) && ref($filter) ne "HASH") {
      $self->argh('filter not scalar or hash');
    }
    unless (ref($filter)) {
      my %f = simple_tokenizer($filter);
      $p{filter} = $filter = \%f;
    }
    if (exists $p{filter}->{schema} && $p{filter}->{schema} =~ /^(\w+)$/) {
      $p{filter}->{schema} .= '\\.\w+';
    }
  }
  my $tree = $self->{_xpl_filter_tree};
  my $type = $p{filter}->{message_type} || '';
  if ($type =~ /^xpl-(cmnd|stat|trig)$/) {
    delete $p{filter}->{message_type};
  } else {
    $type = '';
  }
  my $schema = $p{filter}->{schema} || '';
  if ($schema =~ /^\w+\.\w+$/) {
    delete $p{filter}->{schema};
  } else {
    $schema = '';
  }
  $tree->{$type}->{$schema}->{$p{id}} = 1;
  $p{tree} = $tree->{$type}->{$schema};
  delete $p{filter} unless (keys %{$p{filter}});
  #print STDERR "Added ", $p{id}, " to tree ", ${type}, " -> ", ${schema}, "\n";
  return $self->add_callback_item('xpl_callback', $p{id}, \%p);
}

=head2 C<exists_xpl_callback($id)>

This method returns true if an xPL message callback with the given id
is registered.

=head2 C<remove_xpl_callback($id)>

This method removes the registered xPL message callback for the given
id.

=cut

sub remove_xpl_callback {
  my ($self, $id) = @_;
  $self->exists_xpl_callback($id) or
    return $self->ouch("xpl_callback '$id' not registered");
  delete $self->xpl_callback_attrib($id, 'tree')->{$id};
  $self->remove_item('xpl_callback', $id);
  return 1;
}



=head2 C<xpl_callback_attrib($id, $attrib)>

This method returns the value of the attribute of the callback with
the given id.

=head2 C<xpl_callback_callback_count($id)>

This method returns the callback count of the xPL callback with
the given id.

=head2 C<xpl_callback_callback_time_total($id)>

This method returns the total time spent inside the xPL callback with
the given id.

=head2 C<xpl_callback_callback_time_max($id)>

This method returns the maximum time spent during a single execution
of the xPL callback with the given id.

=head2 C<xpl_callback_callback_time_average($id)>

This method returns the average time spent during a single execution
of the xPL callback with the given id.  It returns undef if the
callback has never been called.

=cut

sub xpl_callback_callback_time_average {
  my $self = shift;
  my $count = $self->xpl_callback_callback_count(@_);
  return unless ($count);
  return $self->xpl_callback_callback_time_total(@_)/$count;
}

=head2 C<xpl_callbacks()>

This method returns a list of the registered xPL callbacks.

=head2 C<xpl_message($file_handle)>

This method is called when another xPL message has arrived.  It
constructs the L<xPL::Message> object and if the message is valid,
calls the L<dispatch_xpl_message()> method to pass it on to relevant
xpl_callbacks.

=cut

sub xpl_message {
  my $self = shift;
  my $sock = $self->{_listen_sock};
  my $buf = '';
  my $addr = recv($sock, $buf, 1500, 0);
  my ($peerport, $peeraddr) = sockaddr_in($addr);
  $peeraddr = inet_ntoa($peeraddr);
  my $msg;
  eval {
    $msg = xPL::Message->new_from_payload($buf);
  };
  if ($@) {
    warn "Invalid message from $peeraddr:$peerport: $@";
    return 1;
  }

  return $self->dispatch_xpl_message($msg, $peeraddr, $peerport);
}

=head2 C<dispatch_xpl_message($msg, $peeraddr, $peerport)>

This method is used to dispatch an xPL message to the relevant
xpl_callbacks.

=cut

sub dispatch_xpl_message {
  my ($self, $msg, $peeraddr, $peerport) = @_;

  my $can_id = $self->can('id');
  my $own_message = $can_id && $msg->source eq $self->id;
  my $not_for_us = $can_id && $msg->target ne '*' && $msg->target ne $self->id;

  my $message_type = $msg->message_type;
  my $schema = $msg->schema;
  my $tree = $self->{_xpl_filter_tree};
  my @callbacks = (keys %{$tree->{$message_type}->{$schema}},
                   keys %{$tree->{$message_type}->{''}},
                   keys %{$tree->{''}->{$schema}},
                   keys %{$tree->{''}->{''}});
 CB:
  foreach my $id (@callbacks) {
    next if ($own_message && $self->xpl_callback_self_skip($id));
    next if ($not_for_us && $self->xpl_callback_targeted($id));
    my $filter = $self->xpl_callback_filter($id);
    if (defined $filter) {
      foreach my $key (keys %$filter) {
        my $val = $msg->field($key);
        $val = $msg->$key if (!defined $val && $msg->can($key));
        next CB unless (defined $val);
        my $match = $filter->{$key};
        if (ref($match) eq 'CODE') {
          next CB unless (&{$match}($val));
        } else {
          next CB unless ($val =~ $match);
        }
      }
    }
    $self->call_callback('xpl_callback', $id,
                         message => $msg,
                         peeraddr => $peeraddr,
                         peerport => $peerport,
                        );
  }

  return 1;
}

=head1 EVENT LOOP METHODS

=head2 C<main_loop( [ $count ] )>

This is the main event loop.  This method handles waiting on the
registered input handles and subsequent dispatch of callbacks.  It
also handles the dispatch of timer events.  Normally the main loop
should be run forever, but an optional count can be passed to
force the loop to exit after that number of iterations.

=cut

sub _default_main_loop {
  my ($self, $count) = @_;

  local $SIG{'USR1'} = sub { $self->dump_statistics };
  my $sub = sub { $self->exiting(@_) };
  local $SIG{'INT'} = $sub;
  local $SIG{'QUIT'} = $sub;
  local $SIG{'TERM'} = $sub;

  my $select = $self->{_select} = IO::Select->new();
  $select->add($_) foreach ($self->inputs);

  while (!defined $count || $count-- > 0) {
    my $timeout = $self->timer_minimum_timeout();
    my @ready = $select->can_read($timeout);
    foreach my $handle (@ready) {
      $self->dispatch_input($handle);
    }
    $self->dispatch_timers();
  }
  return 1;
}

sub _anyevent_main_loop {
  my ($self, $count) = @_;

  local $SIG{'USR1'} = sub { $self->dump_statistics };
  my $sub = sub { $self->exiting(@_) };
  local $SIG{'INT'} = $sub;
  local $SIG{'QUIT'} = $sub;
  local $SIG{'TERM'} = $sub;

  if (defined $count) {
    warnings::warnif('deprecated' => 'main_loop with count is deprecated.');
    while ($count > 0) {
      if ($self->module_available('AnyEvent::Loop')) {
        AnyEvent::Loop->one_event;
      } else {
        AnyEvent->one_event;
      }
      $count--;
    }
  } else {
    my $exit = AnyEvent->condvar;
    $exit->recv;
  }
  return 1;
}

=head2 C<cleanup( )>

This method removes all timers and inputs.  It is called by the
destructor.

=cut

sub cleanup {
  my $self = shift;
  return unless ($self->{_is_initialized});
  foreach my $t ($self->timers) {
    $self->remove_timer($t);
  }
  foreach my $i ($self->inputs) {
    next unless (defined $i);
    $self->remove_input($i);
  }
}

=head2 C<exit( )>

This method closes down the client.

=cut

sub exit {
  $_[0]->exiting();
}

=head2 C<exiting( )>

This method is called when we are exiting and can be overridden to provide
additional behaviour.  When overridden the exiting method should probably
end with:

  return $self->SUPER::exiting(@_);

=cut

sub exiting {
  # do nothing
  CORE::exit;
}

=head1 TIMER METHODS

=head2 C<add_timer(%params)>

This method registers a timer with the event loop.  It takes a parameter
hash as arguments.  The valid keys are:

=over 4

=item id

This is a unique identifier used to manage this timer record.

=item timeout

The interval in seconds between dispatch of this timer.  Negative
values mean that the timer should be triggered for the first time as
soon as possible rather than after the given interval.  Timeouts
beginning with "C " have these characters removed and then the
remaining string is passed to a L<DateTime::Event::Cron> object for
processing.

=item callback

This is the callback to executed when the timer is dispatched.
It must return true if it is to be dispatched again otherwise
it will be removed from the event loop.

=item arguments

These arguments are passed to the callback when it is executed.

=item count

This argument is optional.  It is a count of the number of times
that the timer should be dispatched before being removed from the event
loop.

=back

=cut

sub add_timer {
  my $self = shift;
  my %p = @_;
  exists $p{id} or $self->argh("requires 'id' parameter");
  exists $p{timeout} or $self->argh("requires 'timeout' parameter");
  my $id = $p{id};
  $self->exists_timer($id) and
    $self->argh("timer '".$id."' already exists");

  my $time = time_now();
  my $timeout = $p{timeout};
  my $timer = xPL::Timer->new_from_string($timeout);
  my $next_fn = sub { $timer->next(@_) };
  my $next;
  if ($timeout =~ /^-[0-9\.]+$/) {
    $next = $time;
  } else {
    $next = $next_fn->($time);
  }

  $p{next_fn} = $next_fn;
  $p{timer} = $timer;
  $self->add_callback_item('timer', $id, \%p);
  $self->timer_next($id, $next);
  return 1;
}

=head2 C<exists_timer($id)>

This method returns true if the timer with the given id is registered
with the event loop.

=head2 C<remove_timer($id)>

This method drops the timer with the given id from the event loop.

=cut

sub _default_remove_timer {
  my $self = shift;
  my $id = shift;
  $self->exists_timer($id) or
    return $self->ouch("timer '$id' not registered");
  $self->remove_item('timer', $id);
  return 1;
}

sub _anyevent_remove_timer {
  my $self = shift;
  my $id = shift;
  $self->exists_timer($id) or
    return $self->ouch("timer '$id' not registered");

  my $ae = $self->timer_attrib($id, 'anyevent');
  if ($ae) {
    undef $ae;
    $self->timer_attrib($id, 'anyevent', 0);
  }

  $self->remove_item('timer', $id);
  return 1;
}

=head2 C<timers()>

This method returns the ids of all the registered timers.

=head2 C<timer_attrib($id, $attrib)>

This method returns the value of the attribute of the timer with the
given id.

=head2 C<timer_next($id, [$next])>

This method returns the time that the timer with the given id is next
due to expire.

=cut

sub _default_timer_next {
  my $self = shift;
  my $id = shift;
  return $self->timer_attrib($id, 'next', @_);
}

sub _anyevent_timer_next {
  my ($self, $id, $next) = @_;
  return $self->timer_attrib($id, 'next') unless (defined $next);
  my $time = time_now();
  $self->timer_anyevent($id,
                        AnyEvent->timer(after => ($next - $time),
                                        cb => sub {
                                          $self->dispatch_timer($id);
                                        }));
  return $self->timer_attrib($id, 'next', $next);
}

=head2 C<timer_callback_count($id)>

This method returns the callback count of the timer with the given id.

=head2 C<timer_callback_time_total($id)>

This method returns the total time spent inside the timer callback with
the given id.

=head2 C<timer_callback_time_max($id)>

This method returns the maximum time spent during a single execution
of the timer callback with the given id.

=head2 C<timer_callback_time_average($id)>

This method returns the average time spent during a single execution
of the timer callback with the given id.  It returns undef if the
callback has never been called.

=cut

sub timer_callback_time_average {
  my $self = shift;
  my $count = $self->timer_callback_count(@_);
  return unless ($count);
  return $self->timer_callback_time_total(@_)/$count;
}

=head2 C<timer_timeout($id)>

This method returns the timeout of the timer with the given id.

=head2 C<timer_next_ticks()>

This method returns the times of the next dispatch of the all the
timers registered with the event loop.

=cut

sub timer_next_ticks {
  my $self = shift;
  my @t = map { $self->timer_attrib($_, 'next') } $self->timers();
  return wantarray ? @t : \@t;
}

=head2 C<timer_minimum_timeout()>

This method returns the amount of time remaining before the next timer
is due to be dispatched.

=cut

sub timer_minimum_timeout {
  my $self = shift;
  my $t = time_now();
  my $min = min($self->timer_next_ticks);
  return $min ? $min-$t : undef;
}

=head2 C<reset_timer($id, [ $time ])>

This method resets the timer to run from now (or the optional given time).

=cut

sub reset_timer {
  my $self = shift;
  my $id = shift;
  $self->exists_timer($id) or
    return $self->ouch("timer '$id' not registered");

  my $time = shift || time_now();
  my $next = $self->timer_next_fn($id)->($time);
  $self->timer_next($id, $next);
  return 1;
}

=head2 C<dispatch_timer($id)>

This method dispatches the callback for the given timer.

=cut

sub dispatch_timer {
  my $self = shift;
  my $id = shift;
  $self->exists_timer($id) or
    return $self->ouch("timer '$id' not registered");

  my $res = $self->call_callback('timer', $id);
  if (!defined $res or !$res) {
    $self->remove_timer($id);
    return;
  } elsif ($res == -1) {
    return;
  } elsif ($self->exists_timer($id) && defined $self->timer_count($id)) {
    my $count = $self->timer_count($id);
    $count--;
    $self->timer_count($id, $count);
    unless ($count > 0) {
      $self->remove_timer($id);
      return;
    }

  }
  $self->reset_timer($id) if ($self->exists_timer($id));
  return $res;
}

=head2 C<dispatch_timers()>

This method dispatches any timers that have expired.

=cut

sub dispatch_timers {
  my $self = shift;
  my $t = time_now();
  foreach my $id ($self->timers) {
    next unless ($self->timer_next($id) <= $t);
    $self->dispatch_timer($id);
  }
  return 1;
}

=head1 INPUT MONITORING METHODS

=head2 C<add_input(%params)>

This method registers an input file handle (often a socket) with the
event loop.  It takes a parameter hash as arguments.  The valid keys
are:

=over 4

=item handle

This is file handle of the input to be monitored.  The handle is
used to uniquely identify the callback and is required to manipulate
the record of this input.  (Strictly speaking it is actually the
string representation of the handle which is used but typically
you don't need to worry about this distinction.)

=item callback

This is the callback to executed when the handle has input to be read.
It should return true.  It will be passed the handle as the first
argument and the arguments below as an array reference as an array
reference as the second.

=item arguments

These arguments are passed to the callback when it is executed.  These
arguments are passed as an array reference after the mandatory
arguments mentioned above.

=back

=cut

sub _default_add_input {
  my $self = shift;
  my %p = @_;
  exists $p{handle} or $self->argh("requires 'handle' argument");
  $self->add_callback_item('input', $p{handle}, \%p);
  if ($self->{_select}) {
    $self->{_select}->add($p{handle});
  }
  return 1;
}

sub _anyevent_add_input {
  my $self = shift;
  my %p = @_;
  exists $p{handle} or $self->argh("requires 'handle' argument");
  my $handle = $p{handle};
  $p{anyevent} = AnyEvent->io(fh => $handle, poll => 'r',
                              cb => sub {
                                $self->dispatch_input($handle)
                              });
  $self->add_callback_item('input', $handle, \%p);
  return 1;
}

=head2 C<inputs()>

This method returns a list of the registered input handles.  Note,
this method returns the real file handles and not the strings that
are used as the keys internally.

=cut

sub inputs {
  my $self = shift;
  return map { $self->input_attrib($_, 'handle') } $self->items('input');
}

=head2 C<exists_input($handle)>

This method returns true if the given handle is registered with the
event loop.

=head2 C<remove_input($handle)>

This method drops the given handle from the event loop.

=cut

sub _default_remove_input {
  my $self = shift;
  my $handle = shift;
  $self->exists_input($handle) or
    return $self->ouch("input '$handle' not registered");

  if ($self->{_select}) {
    # make sure we have the real thing not just a string
    my $real = $self->input_handle($handle);
    $self->{_select}->remove($real);
  }

  $self->remove_item('input', $handle);
  return 1;
}

sub _anyevent_remove_input {
  my $self = shift;
  my $handle = shift;
  $self->exists_input($handle) or
    return $self->ouch("input '$handle' not registered");

  my $ae = $self->input_attrib($handle, 'anyevent');
  if ($ae) {
    undef $ae;
    $self->input_attrib($handle, 'anyevent', 0);
  }

  $self->remove_item('input', $handle);
  return 1;
}

=head2 C<input_attrib($handle, $attrib)>

This method returns the value of the attribute of the registered input with
the given handle.

=head2 C<input_callback_count($handle)>

This method returns the callback count of the registered input with
the given handle.

=head2 C<input_callback_time_total($id)>

This method returns the total time spent inside the input callback with
the given id.

=head2 C<input_callback_time_max($id)>

This method returns the maximum time spent during a single execution
of the input callback with the given id.

=head2 C<input_callback_time_average($id)>

This method returns the average time spent during a single execution
of the input callback with the given id.  It returns undef if the
callback has never been called.

=cut

sub input_callback_time_average {
  my $self = shift;
  my $count = $self->input_callback_count(@_);
  return unless ($count);
  return $self->input_callback_time_total(@_)/$count;
}

=head2 C<dispatch_input($handle)>

This method dispatches the callback for the given input handle.

=cut

sub dispatch_input {
  my $self = shift;
  my $handle = shift;
  $self->exists_input($handle) or
    return $self->ouch("input '$handle' not registered");
  return $self->call_callback('input', $handle,
                              $self->input_handle($handle),
                              $self->input_arguments($handle));
}

=head2 C<dump_statistics()>

This method dumps our statistics to stderr.

=cut

sub dump_statistics {
  my $self = shift;
  my %m = map { $_ => ($self->timer_callback_time_average($_)||-1)
              } $self->timers;
  print STDERR "Timers\n";
  foreach my $id (sort { $m{$b} <=> $m{$a} } keys %m) {
    printf STDERR "%10.7f %s\n", $m{$id}, $id;
  }
  %m = map { $_ => ($self->input_callback_time_average($_)||-1)
           } $self->inputs;
  print STDERR "Inputs\n";
  foreach my $id (sort { $m{$b} <=> $m{$a} } keys %m) {
    printf STDERR "%10.7f %s\n", $m{$id}, $id;
  }
  %m = map { $_ => ($self->xpl_callback_callback_time_average($_)||-1)
           } $self->xpl_callbacks;
  print STDERR "xPL Callbacks\n";
  foreach my $id (sort { $m{$b} <=> $m{$a} } keys %m) {
    printf STDERR "%10.7f %s\n", $m{$id}, $id;
  }
  return 1;
}

=head2 C<time_now( )>

This method returns the current time for use in event loop callbacks.

=cut

sub _default_time_now {
  Time::HiRes::time;
}

sub _anyevent_time_now {
  AnyEvent->time;
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

Copyright (C) 2005, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
