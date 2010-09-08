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
use FileHandle;
use xPL::RF;
use xPL::X10 qw/:all/;
use xPL::HomeEasy qw/:all/;
use xPL::IOHandler;
use xPL::Dock::Plug;
use xPL::IORecord::Hex;

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
  $self->{_x10} = 1;
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
  my %p = @_;

  $self->required_field($xpl,
                        'device',
                        'The --rfxcom-tx-tty parameter is required', 1);
  $self->SUPER::init($xpl, @_);

  my $io = $self->{_io} =
    xPL::IOHandler->new(xpl => $self->{_xpl}, verbose => $self->verbose,
                        device => $self->{_device},
                        baud => $self->{_baud},
                        ack_timeout => 6,
                        ack_timeout_callback => sub { $self->reset_device(@_) },
                        reader_callback => sub { $self->device_reader(@_) },
                        input_record_type => 'xPL::IORecord::Hex',
                        output_record_type => 'xPL::IORecord::Hex');


  # Add a callback to receive incoming xPL messages
  $xpl->add_xpl_callback(id => 'xpl-x10', callback => \&xpl_x10,
                         arguments => $self,
                         filter =>
                         {
                          message_type => 'xpl-cmnd',
                          class => 'x10.basic',
                         });

  $xpl->add_xpl_callback(id => 'xpl-homeeasy', callback => \&xpl_homeeasy,
                         arguments => $self,
                         filter =>
                         {
                          message_type => 'xpl-cmnd',
                          class => 'homeeasy.basic',
                         });

  $self->{_rf} = xPL::RF->new(source => $xpl->id);

  $io->write(hex => 'F030F030', desc => 'init/version check');
  $self->init_device();
  $io->write(hex => 'F03CF03C', desc => 'enabling harrison')
    if ($self->harrison);
  $io->write(hex => 'F03DF03D', desc => 'enabling klikon-klikoff')
    if ($self->koko);
  $io->write(hex => 'F03EF03E', desc => 'enabling flamingo')
    if ($self->flamingo);
  $io->write(hex => 'F03FF03F', desc => 'disabling x10')
    unless ($self->x10);

  return $self;
}

=head2 C<xpl_x10(%xpl_callback_parameters)>

This is the callback that processes incoming xPL messages.  It handles
the incoming x10.basic schema messages.

=cut

sub xpl_x10 {
  my %p = @_;
  my $msg = $p{message};
  my $peeraddr = $p{peeraddr};
  my $peerport = $p{peerport};
  my $self = $p{arguments};

  if ($msg->field('house')) {
    foreach (split //, $msg->field('house')) {
      my $rf_msg =
        xPL::IORecord::Hex->new(raw => encode_x10(command => $msg->field('command'),
                                                  house => $msg->field('house')),
                 desc => $msg->field('house').' '.$msg->field('command'));
      foreach (1..$msg->field('repeat')||1) {
        $self->{_io}->write($rf_msg);
      }
    }
  } elsif ($msg->field('device')) {
    foreach (split /,/, $msg->field('device')) {
      my ($house, $unit) = /^([a-p])(\d+)$/i or next;
      my $rf_msg =
        xPL::IORecord::Hex->new(raw => encode_x10(command => $msg->field('command'),
                                                  house => $house,
                                                  unit => $unit),
                                desc => $house.$unit.' '.$msg->field('command'));
      foreach (1..$msg->field('repeat')||1) {
        $self->{_io}->write($rf_msg);
      }
    }
  } else {
    warn "Invalid x10.basic message:\n  ", $msg->summary, "\n";
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
  my $peeraddr = $p{peeraddr};
  my $peerport = $p{peerport};
  my $self = $p{arguments};

  my %args = ();
  foreach (qw/address unit command/) {
    my $val = $msg->field($_) or do {
      warn "Invalid homeeasy.basic message:\n  ", $msg->summary, "\n";
      return;
    };
    $args{$_} = $val;
  }
  if ($args{command} eq 'preset') {
    my $level = $msg->field('level');
    unless (defined $level) {
      warn "homeeasy.basic 'preset' message is missing 'level':\n  ",
        $msg->summary, "\n";
      return;
    }
    $args{level} = $level;
  }
  my $rf_msg = xPL::IORecord::Hex->new(raw => encode_homeeasy(%args),
                                       desc => $msg->summary);
  foreach (1..$msg->field('repeat')||1) {
    $self->{_io}->write($rf_msg);
  }
  return 1;
}

=head2 C<device_reader()>

This is the callback that processes output from the RFXCOM transmitter.
It is responsible for reading the 'ACK' messages and sending out any
queued transmit messages.

=cut

sub device_reader {
  my ($self, $handler, $msg, $last) = @_;
  # TOFIX: send confirm messages?
  print 'received: ', $msg, "\n";
  return 1;
}

=head2 C<init_device( )>

This method sends the initialization command to the RFXCom transmitter.

=cut

sub init_device {
  my ($self) = @_;
  $self->{_io}->write($self->receiver_connected ?
                      (hex => 'F033F033',
                       desc => 'variable length mode w/receiver connected') :
                      (hex => 'F037F037',
                       desc => 'variable length mode w/o receiver connected'));
}

=head2 C<reset_device( $waiting )>

This is the ACK timeout callback that attempts to reset the device if
it has not responded to a command.

=cut

sub reset_device {
  my ($self, $waiting) = @_;
  print STDERR "No ack!\n";
  $self->init_device();
  1;
}

=head2 C<encode_x10( %p )>

This function creates the RFXCom transmitter message for the given
the X10 message specification.

=cut

sub encode_x10 {
  return pack 'C5', 32, @{xPL::X10::to_rf(@_)};
}

=head2 C<encode_homeeasy( %p )>

This function creates the RFXCom transmitter message for the given
the homeeasy message specification.

=cut

sub encode_homeeasy {
  my ($length, $bytes) = @{xPL::HomeEasy::to_rf(@_)};
  return pack 'C6', $length, @$bytes;
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
