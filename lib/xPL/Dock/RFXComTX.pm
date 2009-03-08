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
use Time::HiRes;
use IO::Socket::INET;
use Pod::Usage;
use xPL::Dock::Serial;
use xPL::Queue;
use xPL::RF;
use xPL::X10 qw/:all/;
use xPL::HomeEasy qw/:all/;

our @ISA = qw(xPL::Dock::Serial);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

our @fields = qw/receiver_connected flamingo harrison koko x10/;

__PACKAGE__->make_readonly_accessor($_) foreach (@fields);

{ # shortcut to save typing
  package Msg;
  use base 'xPL::BinaryMessage';
  1;
}

sub getopts {
  my $self = shift;
  $self->{_baud} = 4800;
  $self->{_x10} = 1;
  my @opts = (
              'rfxcom-tx-baud|rfxcomtxbaud=i' => \$self->{_baud},
              'rfxcom-tx|rfxcomtx=s' => \$self->{_device},
             );
  foreach (@fields) {
    $self->{'_'.$_} = undef;
    push @opts, $_ => \$self->{'_'.$_};
  }
  return @opts;
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;
  my %p = @_;

  defined $self->{_device} or
    pod2usage(-message => "The --rfxcom-tx parameter is required",
              -exitstatus => 1);
  $self->SUPER::init($xpl,
                     ack_timeout => 6,
                     ack_timeout_callback => \&reset_device,
                     reader_callback => \&device_reader,
                     @_);

  # Add a callback to receive incoming xPL messages
  $xpl->add_xpl_callback(id => 'xpl-x10', callback => \&xpl_x10,
                         arguments => $self,
                         filter =>
                         {
                          message_type => 'xpl-cmnd',
                          class => 'x10',
                          class_type => 'basic',
                         });

  $xpl->add_xpl_callback(id => 'xpl-homeeasy', callback => \&xpl_homeeasy,
                         arguments => $self,
                         filter =>
                         {
                          message_type => 'xpl-cmnd',
                          class => 'homeeasy',
                          class_type => 'basic',
                         });

  $self->{_rf} = xPL::RF->new(source => $xpl->id) or
    $self->argh("Failed to create RF decode object\n");

  $self->write(Msg->new(hex => 'F030F030', desc => 'init/version check'));
  $self->init_device();
  $self->write(Msg->new(hex => 'F03CF03C', desc => 'enabling harrison'))
    if ($self->harrison);
  $self->write(Msg->new(hex => 'F03DF03D', desc => 'enabling klikon-klikoff'))
    if ($self->koko);
  $self->write(Msg->new(hex => 'F03EF03E', desc => 'enabling flamingo'))
    if ($self->flamingo);
  $self->write(Msg->new(hex => 'F03FF03F', desc => 'disabling x10'))
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

  if ($msg->house) {
    foreach (split //, $msg->house) {
      my $rf_msg =
        Msg->new(raw => encode_x10(command => $msg->command,
                                   house => $msg->house),
                 desc => $msg->house.' '.$msg->command);
      foreach (1..$msg->extra_field('repeat')||1) {
        $self->write($rf_msg);
      }
    }
  } elsif ($msg->device) {
    foreach (split /,/, $msg->device) {
      my ($house, $unit) = /^([a-p])(\d+)$/i or next;
      my $rf_msg =
        Msg->new(raw => encode_x10(command => $msg->command,
                                   house => $house,
                                   unit => $unit),
                 desc => $house.$unit.' '.$msg->command);
      foreach (1..$msg->extra_field('repeat')||1) {
        $self->write($rf_msg);
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
    my $val = $msg->$_ or do {
      warn "Invalid homeeasy.basic message:\n  ", $msg->summary, "\n";
      return;
    };
    $args{$_} = $val;
  }
  if ($args{command} eq 'preset') {
    my $level = $msg->level;
    unless (defined $level) {
      warn "homeeasy.basic 'preset' message is missing 'level':\n  ",
        $msg->summary, "\n";
      return;
    }
    $args{level} = $level;
  }
  my $rf_msg = Msg->new(raw => encode_homeeasy(%args), desc => $msg->summary);
  foreach (1..$msg->extra_field('repeat')||1) {
    $self->write($rf_msg);
  }
  return 1;
}

=head2 C<device_reader()>

This is the callback that processes output from the RFXCOM transmitter.
It is responsible for reading the 'ACK' messages and sending out any
queued transmit messages.

=cut

sub device_reader {
  my ($self, $buf) = @_;
  print 'received: ', unpack('H*', $buf), "\n";
  return '';
}

sub init_device {
  my ($self) = @_;
  $self->write($self->receiver_connected ?
               Msg->new(hex => 'F033F033',
                        desc =>
                        'variable length mode w/receiver connected') :
               Msg->new(hex => 'F037F037',
                        desc =>
                        'variable length mode w/o receiver connected'));
}

sub reset_device {
  my ($self, $waiting) = @_;
  print STDERR "No ack!\n";
  $self->init_device();
  1;
}

sub encode_x10 {
  return pack 'C5', 32, @{xPL::X10::to_rf(@_)};
}

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
