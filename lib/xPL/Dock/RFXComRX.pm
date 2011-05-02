package xPL::Dock::RFXComRX;

=head1 NAME

xPL::Dock::RFXComRX - xPL::Dock plugin for an RFXCom Receiver

=head1 SYNOPSIS

  use xPL::Dock qw/RFXComRX/;
  my $xpl = xPL::Dock->new();
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
use AnyEvent::RFXCOM::RX;
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
  $self->{_baud} = 4800;
  return
    (
     'rfxcom-rx-verbose+' => \$self->{_verbose},
     'rfxcom-rx-baud=i' => \$self->{_baud},
     'rfxcom-rx-tty=s' => \$self->{_device},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;

  $self->required_field($xpl,
                        'device',
                        'The --rfxcom-rx-tty parameter is required', 1);
  $self->SUPER::init($xpl, @_);

  $self->{rx} =
    AnyEvent::RFXCOM::RX->new(device => $self->{_device},
                              baud => $self->{_baud},
                              callback => sub { $self->device_reader(@_);
                                                $self->{_got_message}++ });

  return $self;
}

=head2 C<device_reader()>

This is the callback that processes output from the RFXCOM.  It is
responsible for sending out the xPL messages.

=cut

sub device_reader {
  my ($self, $res) = @_;
  my $xpl = $self->xpl;
  print "Processed: ", $res->summary, "\n" if ($self->verbose);
  $self->{_last_res} = $res;
  return 1 if ($res->duplicate);
  foreach my $m (@{$res->messages||[]}) {
    if ($m->type eq 'x10') {

      my @body;
      push @body, command => $m->command;
      push @body, device => $m->device if ($m->device);
      push @body, house => $m->house if ($m->house);
      push @body, level => $m->level if ($m->level);

      print $xpl->send(message_type => 'xpl-trig',
                       schema => 'x10.basic',
                       body => \@body)->summary,"\n";

    } elsif ($m->type eq 'homeeasy') {

      my @body;
      push @body, address => $m->address;
      push @body, unit => $m->unit;
      push @body, command => $m->command;
      push @body, level => $m->level if ($m->level);

      print $xpl->send(message_type => 'xpl-trig',
                       schema => 'homeeasy.basic',
                       body => \@body)->summary,"\n";

    } elsif ($m->type eq 'sensor') {

      $xpl->send_sensor_basic($m->device, $m->measurement,
                              $m->value, $m->units);

    } elsif ($m->type eq 'security') {

      my ($t, $id) = split /\./, $m->device, 2;
      if ($t eq 'powercode' || $m->device =~ /x10sec/) {
        if ($m->event =~ /^(alert|normal)$/) {
          my @body;
          push @body, event => 'alert';
          push @body, zone => $m->device;
          push @body, state => $m->event eq 'normal' ? 'false' : 'true';
          push @body, delay  => 'min' if ($m->min_delay && $m->device =~ /x10sec/);
          push @body, tamper => $m->tamper ? 'true' : 'false' if ($m->tamper);
          print $xpl->send(message_type => 'xpl-trig',
                           schema => 'security.zone',
                           body => \@body)->summary, "\n";
        } else {
          my @body;
          push @body, command => $m->event;
          push @body, delay  => 'min' if ($m->min_delay);
          push @body, user => $m->device;
          print $xpl->send(message_type => 'xpl-trig',
                           schema => 'security.basic',
                           body => \@body)->summary, "\n";
        }
      }
      my @body;
      push @body, command => $m->event;
      if ($m->device =~ /^x10sec(.*)$/) {
        push @body, device => hex($1);
        push @body, tamper => $m->tamper ? 'true' : 'false' if ($m->tamper);
        push @body, delay  => 'min' if ($m->min_delay);
      } else {
        push @body, device => $id;
        push @body, type => $t;
        push @body, tamper => $m->tamper ? 'true' : 'false' if ($m->tamper);
        push @body, min_delay => $m->min_delay if ($m->min_delay);
      }

      print $xpl->send(message_type => 'xpl-trig',
                       schema => 'x10.security',
                       body => \@body)->summary,"\n";

    } elsif ($m->type eq 'datetime') {

      my @body;
      push @body, datetime => $m->date.$m->time;
      push @body, 'date' => $m->date;
      push @body, 'time' => $m->time;
      push @body, day => $m->day;
      print $xpl->send(message_type => 'xpl-trig',
                       schema => 'datetime.basic',
                       body => \@body)->summary,"\n";
    } else {
      $self->ouch("RF message: ", $m->summary, " not supported\n");
    }
  }
  return 1;
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
