package xPL::RF::Electrisave;

# $Id$

=head1 NAME

xPL::RF::Electrisave - Perl extension for an xPL RF Class

=head1 SYNOPSIS

  use xPL::RF::Electrisave;

=head1 DESCRIPTION

This is a module contains a module for handling the decoding of RF
messages.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use English qw/-no_match_vars/;
use xPL::Message;
use Exporter;
#use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.01';
our $SVNVERSION = qw/$Revision$/[1];

=head2 C<parse( $parent, $message, $bytes, $bits )>

TODO: POD

TODO: The duplicates should probably be counted for bright and dim to set
the level but they aren't yet.

=cut

sub parse {
  my $self = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  $bits == 120 or return;

  ($bytes->[0] == 0xea && ($bytes->[1]&0xf0) == 0x00) or return;

  my $device = sprintf "%02x", $bytes->[2];
  my $amps = ( $bytes->[3]+(($bytes->[4]&0x3)<<8) ) / 10;
  my $kwh = ($amps*240)/1000;
  my $pence = 7.572*$kwh;
  #printf "electrisave c=%.2f p=%.2f\n", $amps, $pence;
  return [xPL::Message->new(
                            message_type => 'xpl-trig',
                            class => 'sensor.basic',
                            head => { source => $parent->source, },
                            body => {
                                     device => 'electrisave.'.$device,
                                     type => 'current',
                                     current => $amps,
                                    }
                           )];
}

1;
__END__

=head1 EXPORT

None by default.

=head1 THANKS

Special thanks to RFXCOM, L<http://www.rfxcom.com/>, for their
excellent documentation and for giving me permission to use it to help
me write this code.  I own a number of their products and highly
recommend them.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
