package xPL::RF::HomeEasy;

# $Id$

=head1 NAME

xPL::RF::HomeEasy - Perl extension for an xPL RF Class

=head1 SYNOPSIS

  use xPL::RF::HomeEasy;

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
use xPL::HomeEasy;
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

=cut

sub parse {
  my $self = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  $bits == 34 or return;

  # HomeEasy devices seem to send duplicates with different byte[4] high nibble
  my @b = @{$bytes};
  my $b4 = $b[4];
  $b[4] &= 0xf;
  if ($b[4] != $b4) {
    $parent->is_duplicate($bits, pack "C*", @b) and return [];
    $b[4] = $b4;
  }

  my $res = xPL::HomeEasy::from_rf($bits, $bytes);

#  printf "homeeasy c=%s u=%d a=%x\n",
#    $res->{command}, $res->{unit}, $res->{address};
  my %body = (
              command => $res->{command},
              unit => $res->{unit},
              address => (sprintf "0x%x",$res->{address}),
             );

  $body{level} = $res->{level} if ($res->{command} eq 'preset');

  return [xPL::Message->new(
                            message_type => 'xpl-trig',
                            class => 'homeeasy.basic',
                            head => { source => $parent->source, },
                            body => \%body,
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

Copyright (C) 2008 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
