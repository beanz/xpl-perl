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
use xPL::RF qw/hex_dump/;
use xPL::IOHandler;
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
  my %p = @_;

  $self->required_field($xpl,
                        'device',
                        'The --rfxcom-rx-tty parameter is required', 1);
  $self->SUPER::init($xpl, @_);

  my $io = $self->{_io} =
    xPL::IOHandler->new(xpl => $self->{_xpl}, verbose => $self->verbose,
                        device => $self->{_device},
                        baud => $self->{_baud},
                        reader_callback => sub { $self->device_reader(@_) },
                        input_record_type => 'xPL::IORecord::VariableLength',
                        output_record_type => 'xPL::IORecord::Hex',
                        discard_buffer_timeout => 0.03);

  $self->{_rf} = xPL::RF->new(source => $xpl->id);

  $io->write(hex => 'F020', desc => 'version check');
  $io->write(hex => "F02A", desc => 'enable all possible receiving modes');
  $io->write(hex => 'F041', desc => 'variable length with visonic');

  return $self;
}

=head2 C<device_reader()>

This is the callback that processes output from the RFXCOM.  It is
responsible for sending out the xPL messages.

=cut

sub device_reader {
  my ($self, $handler, $msg, $last) = @_;
  my $xpl = $self->xpl;
  my $res = $self->{_rf}->process_variable_length($msg->raw);
  print "Processed: $msg\n" if ($self->verbose && !$res->{duplicate});
  return 1 unless (ref $res->{messages});
  foreach my $xplmsg (@{$res->{messages}}) {
    print $xplmsg->summary,"\n";
    $xpl->send($xplmsg);
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
