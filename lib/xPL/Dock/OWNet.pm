package xPL::Dock::OWNet;

=head1 NAME

xPL::Dock::OWNet - xPL::Dock plugin for 1-wire support with OWNet protocol

=head1 SYNOPSIS

  use xPL::Dock qw/OWNet/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This L<xPL::Dock> plugin adds 1-wire support using the owfs OWNet protocol
to communicate with an C<owserver> daemon.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use AnyEvent::OWNet;
use xPL::Dock::Plug;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

__PACKAGE__->make_readonly_accessor($_) foreach (qw/host port/);

my %map =
  (
   "temperature" => [ "temp" ],
   'humidity' => [ 'humidity' ],
   'HIH4000/humidity' => [ 'humidity', 1 ],
   'HTM1735/humidity' => [ 'humidity', 2 ],
   'counters.A' => [ 'count', 0 ],
   'counters.B' => [ 'count', 1 ],
   'current' => [ 'current' ],
  );
#my @files = sort keys %map; # would need to re-write tests
my @files = qw!temperature humidity HIH4000/humidity HTM1735/humidity
               counters.A counters.B current!;

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  $self->{_host} = '127.0.0.1';
  $self->{_port} = 4304;
  return (
          'ownet-verbose+' => \$self->{_verbose},
          'ownet-host=s' => \$self->{_host},
          'ownet-port=i' => \$self->{_port},
         );
}

=head2 C<init(%params)>

This method initializes the plugin.  It configures the xPL callback to
handle incoming C<control.basic> messages for 1-wire relays and the timers
for reading 1-wire temperature, humidity and counter devices.

=cut

sub init {
  my $self = shift;
  my $xpl = shift;
  my %p = @_;

  $self->SUPER::init($xpl, @_);

  $self->{_state} = {};

  # Add a callback to receive all incoming xPL messages
  $xpl->add_xpl_callback(id => 'ownet', callback => sub { $self->xpl_in(@_) },
                         filter => {
                                    message_type => 'xpl-cmnd',
                                    schema => 'control.basic',
                                    type => 'output',
                                   });

  # sanity check the inputs immediately and periodically so we keep
  # the current state sane even when owfs device is unplugged, etc.
  $xpl->add_timer(id => 'ownet-read', timeout => -120,
                  callback => sub { $self->ownet_reader(@_); 1; });

  $self->{ow} = AnyEvent::OWNet->new(host => $self->{_host},
                                     port => $self->{_port});

  return $self;
}

=head2 C<xpl_in(%xpl_callback_parameters)>

This is the callback that processes incoming xPL messages.  It handles
the incoming control.basic schema messages.

=cut

sub xpl_in {
  my $self = shift;
  my %p = @_;
  my $msg = $p{message};
  my $peeraddr = $p{peeraddr};
  my $peerport = $p{peerport};

  my $device = uc $msg->field('device');
  my $current = lc $msg->field('current');
  unless ($device =~ /^[0-9A-F]{2}\.[0-9A-F]+$/) {
    return 1;
  }

  my $sub = sub {
    my $res = shift;
    $self->xpl->send(message_type => 'xpl-trig',
                     schema => 'control.confirm',
                     body =>
                     [
                      device => $device,
                      type => $msg->field('type'),
                      current => ($res->{ret} == 0 ?
                                  $msg->field('current') :
                                  'error'),
                     ]
                    );
  };
  my $pio = '/'.$device.'/PIO';
  if ($current eq 'high') {
    $self->ownet_write($pio, 1, $sub);
  } elsif ($current eq 'low') {
    $self->ownet_write($pio, 0, $sub);
  } elsif ($current eq 'pulse') {
    $self->ownet_write($pio, 1,
                       sub {
                         my $res = shift;
                         if ($res->{ret} == 0) {
                           my $w;
                           $w =  AnyEvent->timer(after => 0.15,
                                                 cb => sub {
                                                   $self->ownet_write($pio, 0,
                                                                      $sub);
                                                   undef $w;
                                                 });
                         } else {
                           $sub->($res);
                         }
                       });
  } else {
    $sub->({ ret => -1 });
    warn "Unsupported setting: $current\n";
  }
  return 1;
}

=head2 C<ownet_write( $file, $value )>

This function writes the given value to the named file in the 1-wire
file system.

=cut

sub ownet_write {
  my $self = shift;
  $self->{ow}->write(@_);
}

=head2 C<ownet_reader()>

This is the callback that processes output from the OWFS.  It is
responsible for sending out the sensor.basic xpl-trig messages.

=cut

sub ownet_reader {
  my $self = shift;
  my $ow = $self->{ow};
  my $cv;
  $cv =
    $ow->device_files(
      sub {
        my ($dev, $file, $value) = @_;
        #print STDERR $dev, ' ', $file, ' ', $value, "\n";
        return unless (defined $value);
        $value += 0; # make sure it is a number without whitespace
        my $id = substr $dev, -16, 15;
        my ($type, $index) = @{$map{$file}};
        my $dev_str = $id.(defined $index ? '.'.$index : '');
        $self->xpl->send_sensor_basic($dev_str, $type, $value);
        1;
      }, \@files);
  return 1;
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

xPL::Client(3), xPL::Listener(3)

Project website: http://www.xpl-perl.org.uk/

OWFS website: http://owfs.sourceforge.net/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2005, 2010 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
