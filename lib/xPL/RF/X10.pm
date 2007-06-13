package xPL::RF::X10;

# $Id$

=head1 NAME

xPL::RF::X10 - Perl extension for an xPL RF Class

=head1 SYNOPSIS

  use xPL::RF::X10;

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

my $SPACE = q{ };

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

  ($bits == 32) or return;

  # bits are not reversed yet!
  (($bytes->[2]^0xff) == $bytes->[3] &&
   ($bytes->[0]^0xff) == $bytes->[1] &&
   !($bytes->[2]&0x7)) or return;

  $parent->reverse_bits($bytes);

  my $byte1 = $bytes->[2];
  my $byte3 = $bytes->[0];

  my $unit_cache = $parent->unstash('unit_cache');
  unless ($unit_cache) {
    $unit_cache = $parent->stash('unit_cache', {});
  }
  my $h = house_code($byte3);
  my $f = function($byte1);
  unless ($byte1&1) {
    $unit_cache->{$h} = unit_code($byte1, $byte3);
  }
  my $u = $unit_cache->{$h} or
    do { warn "Don't have unit code for: $h $f\n"; return [] };
  my $k = $h.$u.$SPACE.$f;
  return [$self->x10_xpl_message($parent, $f, $h.$u)];
}

=head2 C<house_code( $byte1 )>

This function takes byte 1 of a processed X10 message sequence and
returns the associated house code.

=cut

sub house_code {
  ('m', 'e', 'c', 'k', 'o', 'g', 'a', 'i',
   'n', 'f', 'd', 'l', 'p', 'h', 'b', 'j')[$_[0] & 0xf];
}

=head2 C<function( $byte1 )>

This function takes byte 1 of a processed X10 message sequence and
returns the associated function.

=cut

sub function {
  $_[0]&0x1 ? ($_[0]&0x8 ? 'dim' : 'bright') : ($_[0]&0x4 ? 'off' : 'on');
}

=head2 C<unit_code( $byte1, $byte3 )>

This function takes bytes 1 and 3 of a processed X10 message sequence
and returns the associated unit code.

=cut

sub unit_code {
  my $b1 = shift;
  my $b3 = shift;
  return 1 + ((($b1&0x2) << 1) +
              (($b1&0x18) >> 3) +
              (($b3&0x20) >> 2));
}

=head2 C<x10_xpl_message( $parent, $command, $device, $level )>

This functions is used to construct x10.basic xpl-trig messages as a
result of RF messages decoded from the RF data.

=cut

sub x10_xpl_message {
  my $self = shift;
  my $parent = shift;
  my $command = shift;
  my $device = shift;
  my $level = shift;
  my %body = ( device => $device, command => $command );
  if ($command eq 'bright' or $command eq 'dim') {
    $body{level} = $level || $parent->{_default_x10_level};
  }
  my %args =
    (
     message_type => 'xpl-trig',
     class => 'x10.basic',
     head => { source => $parent->{_source}, },
     body => \%body,
    );
  return xPL::Message->new(%args);
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

Copyright (C) 2005, 2007 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
