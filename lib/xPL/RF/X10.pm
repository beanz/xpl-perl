package xPL::RF::X10;

=head1 NAME

xPL::RF::X10 - Perl extension for decoding X10 device RF messages

=head1 SYNOPSIS

  use xPL::RF::X10;

=head1 DESCRIPTION

This is a module for decoding RF messages from X10 devices.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use English qw/-no_match_vars/;
use xPL::Message;
use xPL::X10 qw/:all/;
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

This method attempts to recognize and parse RF messages from X10
devices.  If messages are identified, a reference to a list of
xPL::Message objects is returned.  If the message is not recognized,
undef is returned.

TODO: The duplicates should probably be counted for bright and dim to set
the level but they aren't yet.

=cut

sub parse {
  my $self = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  my $res = xPL::X10::from_rf($bytes) or return;

  my $unit_cache = $parent->unstash('unit_cache');
  unless ($unit_cache) {
    $unit_cache = $parent->stash('unit_cache', {});
  }
  my $h = $res->{house};
  my $f = $res->{command};
  if (exists $res->{unit}) {
    $unit_cache->{$h} = $res->{unit};
  }
  my $u = $unit_cache->{$h} or
    do { warn "Don't have unit code for: $h $f\n"; return [] };
  return [$self->x10_xpl_message($parent, $f, $h.$u)];
}

=head2 C<x10_xpl_message( $parent, $command, $device )>

This functions is used to construct x10.basic xpl-trig messages as a
result of RF messages decoded from the RF data.

=cut

sub x10_xpl_message {
  my $self = shift;
  my $parent = shift;
  my $command = shift;
  my $device = shift;
  my $body = [ command => $command, device => $device ];
  if ($command eq 'bright' or $command eq 'dim') {
    push @$body, level => $parent->{_default_x10_level};
  }
  my %args =
    (
     schema => 'x10.basic',
     body => $body,
    );
  return \%args;
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

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2007, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
