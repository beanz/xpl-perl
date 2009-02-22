package xPL::SerialClient::BinaryMessage;

=head1 NAME

xPL::SerialClient - Perl extension for an xPL Serial Device Client

=head1 SYNOPSIS

  use xPL::SerialClient;

  my $xpl = xPL::SerialClient->new();
  $xpl->add_xpl_callback(name => 'xpl',
                         callback => sub { $xpl->tick(@_) },
                        );

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
use Getopt::Long;
use IO::Socket::INET;
use Pod::Usage;
use xPL::Client;

use Exporter;
our @ISA = qw(xPL::Client);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

__PACKAGE__->make_readonly_accessor($_) foreach (qw/baud device
                                                    device_handle
                                                    reader_callback/);

=head2 C<new(%params)>

The constructor creates a new xPL::SerialClient object.  The
constructor takes a parameter hash as arguments.  Valid parameters in
the hash are:

=over 4

=item raw

  The binary of the message.  (One of C<raw> or C<hex> must be provided.)

=item hex

  The hex for the message.  (One of C<raw> or C<hex> must be provided.)

=item desc

  A human-readable description of the message.

=back

It returns a blessed reference when successful or undef otherwise.

=cut

sub new {
  my $pkg = shift;
  if (ref $pkg) { $pkg = ref $pkg }
  my %p = @_;
  bless \%p, $pkg;
  unless (exists $p{hex} or exists $p{raw}) {
    return;
  }
  return \%p;
}

sub hex {
  $_[0]->{hex} or $_[0]->{hex} = unpack 'H*', $_[0]->{raw};
}

sub raw {
  $_[0]->{raw} or $_[0]->{raw} = pack 'H*', $_[0]->{hex};
}

sub str {
  $_[0]->hex.($_[0]->{desc} ? ': '.$_[0]->{desc} : '');
}

use overload ( '""'  => \&str);

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2007, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
