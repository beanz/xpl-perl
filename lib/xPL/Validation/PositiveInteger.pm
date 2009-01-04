package xPL::Validation::PositiveInteger;

# $Id$

=head1 NAME

xPL::Validation::PositiveInteger - Perl extension for xPL Validation +ive int

=head1 SYNOPSIS

  # this class is not expected to be used directly

  use xPL::Validation;

  my $validation = xPL::Validation->new(type => 'PositiveInteger');

=head1 DESCRIPTION

This module creates an xPL validation which validates fields
as positive integers.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use xPL::Validation;
#use AutoLoader qw(AUTOLOAD);

our @ISA = qw(xPL::Validation);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

=head2 C<valid( $value )>

This method returns true if the value is valid.

=cut

sub valid {
  defined $_[1] && $_[1] && $_[1] =~ qr/^\d+$/;
}

=head2 C<error( )>

This method returns a suitable error string for the validation.

=cut

sub error {
  'It should be a positive integer.';
}

1;
__END__

=head2 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2005, 2008 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
