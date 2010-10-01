package xPL::Dock::W800;

=head1 NAME

xPL::Dock::W800 - xPL::Dock plugin for an W800 Receiver

=head1 SYNOPSIS

  use xPL::Dock qw/W800/;
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
use xPL::RF;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

__PACKAGE__->make_readonly_accessor($_) foreach (qw/baud device/);

{
  package xPL::IORecord::W800;
  use base 'xPL::IORecord::Hex';
  sub read {
    length $_[1] >= 4 ? $_[0]->new(raw => substr $_[1], 0, 4, '') : undef;
  }
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
     'w800-verbose+' => \$self->{_verbose},
     'w800-baud=i' => \$self->{_baud},
     'w800-tty=s' => \$self->{_device},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;
  my %p = @_;

  $self->required_field($xpl,
                        'device', 'The --w800-tty parameter is required', 1);
  $self->SUPER::init($xpl, @_);

  my $io = $self->{_io} =
    xPL::IOHandler->new(xpl => $self->{_xpl}, verbose => $self->verbose,
                        device => $self->{_device},
                        baud => $self->{_baud},
                        reader_callback => sub { $self->device_reader(@_) },
                        input_record_type => 'xPL::IORecord::W800',
                        output_record_type => 'xPL::IORecord::Hex');

  $self->{_rf} = xPL::RF->new(source => $xpl->id);

  return $self;
}

=head2 C<device_reader()>

This is the callback that processes output from the W800.  It is
responsible for sending out the xPL messages.

=cut

sub device_reader {
  my ($self, $handler, $msg, $last) = @_;
  my $m = $msg->raw;
  my $xpl = $self->xpl;
  $self->info("Processing: ", $msg, "\n");
  my $res = $self->{_rf}->process_32bit($m);
  return 1 unless (@$res);
  foreach (@$res) {
    my $xplmsg = xPL::Message->new(head => { source => $xpl->id },
                                   message_type => 'xpl-trig', %$_);
    print $xplmsg->summary, "\n";
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
