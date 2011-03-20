package xPL::Dock::CurrentCost;

=head1 NAME

xPL::Dock::CurrentCost - xPL::Dock plugin for an CurrentCost Receiver

=head1 SYNOPSIS

  use xPL::Dock qw/CurrentCost/;
  my $xpl = xPL::Dock->new(name => 'ccost');
  $xpl->main_loop();

=head1 DESCRIPTION

This module creates an xPL client for a serial port-based device.  There
are several usage examples provided by the xPL Perl distribution.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use AnyEvent::CurrentCost;
use Device::CurrentCost::Constants;
use xPL::Dock::Plug;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

__PACKAGE__->make_readonly_accessor($_) foreach (qw/baud device/);

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  # use '--currentcost-baud 9600' for original current cost
  $self->{_baud} = 57600;
  return
    (
     'currentcost-verbose+' => \$self->{_verbose},
     'currentcost-baud=i' => \$self->{_baud},
     'currentcost-tty=s' => \$self->{_device},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;

  $self->required_field($xpl,
                        'device',
                        'The --currentcost-tty parameter is required', 1);
  $self->SUPER::init($xpl, @_);

  $self->{_cc} =
    AnyEvent::CurrentCost->new(device => $self->{_device},
                               baud => $self->{_baud},
                               callback => sub { $self->device_reader(@_) },
                               on_error => sub {
                                 my ($fatal, $err) = @_;
                                 if ($fatal) {
                                   die $err, "\n";
                                 } else {
                                   warn $err, "\n";
                                 }
                               });
  return $self;
}

=head2 C<device_reader()>

This is the callback that processes output from the CurrentCost.  It is
responsible for sending out the xPL messages.

=cut

sub device_reader {
  my ($self, $msg) = @_;
  my $xpl = $self->xpl;
  return unless ($msg->has_readings); # sensor type 1 ?
  my $device =
    ($self->{_cc}->type == CURRENT_COST_ENVY ? 'cc128' : 'curcost').
      '.'.$msg->id.'.'.$msg->sensor;

  foreach my $p (1..3, undef) {
    my $v = $msg->value($p);
    my $dev = $device.($p ? '.'.$p : '');
    my $xplmsg =
      $xpl->send(message_type => 'xpl-trig',
                 schema => 'sensor.basic',
                 body =>
                 [
                  device => $dev,
                  type => 'power',
                  current => 0+$v,
                  units => 'W',
                 ]);
    print $xplmsg->summary, "\n";
  }
  print $xpl->send(message_type => 'xpl-trig',
                   schema => 'sensor.basic',
                   body =>
                   [
                    device => $device,
                    type => 'temp',
                    current => $msg->temperature,
                   ])->summary, "\n";
  return 1;
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

Current Cost website: http://www.currentcost.com/

Current Cost XML Format: http://www.currentcost.com/cc128/xml.htm

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2005, 2010 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
