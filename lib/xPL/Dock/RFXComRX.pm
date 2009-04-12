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
use FileHandle;
use Time::HiRes;
use IO::Socket::INET;
use Pod::Usage;
use xPL::Dock::Serial;
use xPL::Queue;
use xPL::RF qw/hex_dump/;

our @ISA = qw(xPL::Dock::Serial);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

{ # shortcut to save typing
  package Msg;
  use base 'xPL::BinaryMessage';
  1;
}

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
  my %p = @_;

  $self->required_field($xpl,
                        'device',
                        'The --rfxcom-rx-tty parameter is required', 1);
  $self->SUPER::init($xpl,
                     discard_buffer_timeout => 0.03,
                     reader_callback => \&device_reader,
                     @_);
  $self->{_rf} = xPL::RF->new(source => $xpl->id);

  $self->write(Msg->new(hex => 'F020', desc => 'version check'));
  $self->write(Msg->new(hex => "F02A",
                        desc => 'enable all possible receiving modes'));
  $self->write(Msg->new(hex => 'F041', desc => 'variable length with visonic'));

  return $self;
}

=head2 C<device_reader()>

This is the callback that processes output from the RFXCOM.  It is
responsible for sending out the xPL messages.

=cut

sub device_reader {
  my ($self, $buf, $last) = @_;
  my $xpl = $self->xpl;
  my $res = $self->{_rf}->process_variable_length($buf);
  if (defined $res) {
    # truncate buffer by given length
    my $m = substr($buf, 0, $res->{length}, '') if ($res->{length});
    print "Processed: ", unpack("H*", $m), "\n"
      if ($self->verbose && $m && !$res->{duplicate});
    return $buf unless ($res->{messages} && (ref $res->{messages}));
    foreach my $msg (@{$res->{messages}}) {
      print $msg->summary,"\n";
      $xpl->send($msg);
    }
  } else {
    # discard buffer
    print "Not a variable length message: ", hex_dump($buf), "\n";
    $buf = '';
  }
  return $buf;
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
