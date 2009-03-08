package xPL::Dock::SerialLine;

=head1 NAME

xPL::Dock::SerialLine - xPL::Dock plugin for a SerialLine Device

=head1 SYNOPSIS

  use xPL::Dock::SerialLine;

  sub process_buffer {
    my ($xpl, $buffer, $last_sent) = @_;
    ...
    return $buffer; # any unprocessed bytes
  }
  my $xpl = xPL::Dock::SerialLine->new(reader_callback => \&process_buffer);
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
use xPL::Dock::Serial;

our @ISA = qw(xPL::Dock::Serial);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

__PACKAGE__->make_readonly_accessor('input_record_separator');

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;
  my %p = @_;

  $self->SUPER::init($xpl, @_);

  $self->{_output_record_separator} = "\r"
    unless (defined $self->{_output_record_separator});
  my $irs =
    $self->{_input_record_separator} = $p{input_record_separator} || '\r?\n';
  $self->{_input_regexp} = qr/^(.*?)$irs/;

  return;
}

=head2 C<device_reader_wrapper( $handle )>

This method is called when the device is ready for reads.  It manages
the calls to the C<reader_callback>.  Alternatively, clients could
just override this method to implement specific behaviour.

=cut

sub device_reader_wrapper {
  my ($self, $handle) = @_;
  my $bytes = $self->serial_read($handle);
  my $regexp = $self->{_input_regexp};
  while ($self->{_buffer} =~ s/$regexp//o) {
    my $line = $LAST_PAREN_MATCH;
    $self->{_reader_callback}->($self, $line, $self->{_waiting});
    $self->write_next();
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
