package xPL::Dock::RFXComTX;

=head1 NAME

xPL::Dock::RFXComTX - xPL::Dock plugin for an RFXCom Transmitter

=head1 SYNOPSIS

  use xPL::Dock qw/RFXComTX/;
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
use xPL::Dock::Plug;
use AnyEvent::RFXCOM::TX;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

our @fields = qw/receiver_connected flamingo harrison koko x10/;

__PACKAGE__->make_readonly_accessor($_) foreach (@fields);
__PACKAGE__->make_readonly_accessor($_) foreach (qw/baud device/);

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  $self->{_baud} = 4800;
  my @opts = (
              'rfxcom-tx-verbose+' => \$self->{_verbose},
              'rfxcom-tx-baud=i' => \$self->{_baud},
              'rfxcom-tx-tty=s' => \$self->{_device},
             );
  foreach (@fields) {
    my $n = $_;
    $n =~ s/_/-/g;
    $self->{'_'.$_} = undef;
    push @opts, $n.'!' => \$self->{'_'.$_};
  }
  $self->{_x10} = 1;
  return @opts;
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;

  $self->required_field($xpl,
                        'device',
                        'The --rfxcom-tx-tty parameter is required', 1);
  $self->SUPER::init($xpl, @_);

  my @args;
  foreach (@fields) {
    push @args, $_ => $self->{'_'.$_};
  }
  $self->{_tx} =
    AnyEvent::RFXCOM::TX->new(device => $self->{_device},
                              callback => sub { $self->device_reader(@_);
                                                $self->{_got_message}++},
                              @args);

  # Add a callback to receive incoming xPL messages
  $xpl->add_xpl_callback(id => 'xpl-x10', callback => \&xpl_x10,
                         arguments => $self,
                         filter =>
                         {
                          message_type => 'xpl-cmnd',
                          schema => 'x10.basic',
                         });

  $xpl->add_xpl_callback(id => 'xpl-homeeasy', callback => \&xpl_homeeasy,
                         arguments => $self,
                         filter =>
                         {
                          message_type => 'xpl-cmnd',
                          schema => 'homeeasy.basic',
                         });

  return $self;
}

=head2 C<xpl_x10(%xpl_callback_parameters)>

This is the callback that processes incoming xPL messages.  It handles
the incoming x10.basic schema messages.

=cut

sub xpl_x10 {
  my %p = @_;
  my $msg = $p{message};
  my $self = $p{arguments};

  my %args = map { $_ => $msg->field($_) } $msg->body_fields;
  foreach (1..$msg->field('repeat')||1) {
    $self->{_tx}->transmit(type => 'x10', %args);
  }
  return 1;
}

=head2 C<xpl_homeeasy(%xpl_callback_parameters)>

This is the callback that processes incoming xPL messages.  It handles
the incoming homeeasy.basic schema messages.

=cut

sub xpl_homeeasy {
  my %p = @_;
  my $msg = $p{message};
  my $self = $p{arguments};

  my %args = map { $_ => $msg->field($_) } $msg->body_fields;
  foreach (1..$msg->field('repeat')||1) {
    $self->{_tx}->transmit(type => 'homeeasy', %args);
  }
  return 1;
}

=head2 C<device_reader()>

This is the callback that processes output from the RFXCOM transmitter.
It is responsible for reading the 'ACK' messages and sending out any
queued transmit messages.

=cut

sub device_reader {
  my ($self, $data) = @_;
  # TOFIX: send confirm messages?
  print "Received: ", (unpack 'H*', $data), "\n";
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
