package xPL::Dock::UDIN;

=head1 NAME

xPL::Dock::UDIN - xPL::Dock plugin for an UDIN relay module

=head1 SYNOPSIS

  use xPL::Dock qw/UDIN/;
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
  $self->{_baud} = 9600;
  return (
          'udin-verbose+' => \$self->{_verbose},
          'udin-baud=i' => \$self->{_baud},
          'udin-tty=s' => \$self->{_device},
         );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;

  $self->required_field($xpl,
                        'device', 'The --udin-tty parameter is required', 1);

  $self->SUPER::init($xpl, @_);

  $self->{_io} =
    xPL::IOHandler->new(xpl => $self->{_xpl}, verbose => $self->verbose,
                        device => $self->{_device},
                        baud => $self->{_baud},
                        reader_callback => sub { $self->process_line(@_) },
                        ack_timeout => 0.05,
                        input_record_type => 'xPL::IORecord::CRLFLine',
                        output_record_type => 'xPL::IORecord::CRLine',
                        @_);

  $self->SUPER::init($xpl,
                     reader_callback => \&process_line,
                     ack_timeout => 0.05,
                     @_);

  # Add a callback to receive incoming xPL messages
  $xpl->add_xpl_callback(id => 'udin', callback => \&xpl_in,
                         arguments => $self,
                         filter => {
                                    message_type => 'xpl-cmnd',
                                    schema => 'control.basic',
                                    type => 'output',
                                   });

  $self->{_io}->write('?');
  return $self;
}

=head2 C<xpl_in(%xpl_callback_parameters)>

This is the callback that processes incoming xPL messages.  It handles
the incoming control.basic schema messages.

=cut

sub xpl_in {
  my %p = @_;
  my $msg = $p{message};
  my $self = $p{arguments};

  if ($msg->field('device') eq 'debug') {
    $self->{_io}->write('s0');
  }
  return 1 unless ($msg->field('device') =~ /^udin-r(\d+)$/);
  my $num = $LAST_PAREN_MATCH;
  my $command = lc $msg->field('current');
  if ($command eq 'high') {
    $self->{_io}->write(sprintf('n%d', $num));
  } elsif ($command eq 'low') {
    $self->{_io}->write(sprintf('f%d', $num));
  } elsif ($command eq 'pulse') {
    $self->{_io}->write(sprintf('n%d', $num));
    select(undef,undef,undef,0.15); # TODO: use add_timer
    $self->{_io}->write(sprintf('f%d', $num));
  } elsif ($command eq 'toggle') {
    $self->{_io}->write(sprintf('t%d', $num));
  } else {
    warn "Unsupported setting: $command\n";
  }
  return 1;
}

=head2 C<process_line()>

This is the callback that processes lines of output from the UDIN.  It
is responsible for sending out the sensor.basic xpl-trig messages.

=cut

sub process_line {
  my ($self, $msg) = @_[0,2];
  my $line = $msg->raw;
  return unless ($line ne '');
  $self->info("received: '$line'\n");
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
