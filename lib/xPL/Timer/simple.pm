package xPL::Timer::simple;

=head1 NAME

xPL::Timer::simple - Perl extension for xPL simple timer

=head1 SYNOPSIS

  use xPL::Timer;

  my $timer = xPL::Timer->new(type => 'simple', timeout => 30);

=head1 DESCRIPTION

This module creates an xPL timer abstraction for a simple repeating
interval timer.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use Time::HiRes;
require Exporter;

our @ISA = qw(xPL::Timer);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

=head2 C<init(\%parameter_hash)>

This method is called by the xPL::Timer constructor to allow the
sub-class to process the specific initialisation parameters.  This
sub-class supports the following parameter hash values:

=over 4

=item timeout

The timeout in seconds.  Fractional values are permitted.  The sign is
ignored on negative values.

=back

=cut

sub init {
  my $self = shift;
  my $p = shift;
  exists $p->{timeout} or $self->argh("requires 'timeout' parameter");
  my $timeout = $p->{timeout};
  unless ($timeout =~ /^-?[0-9\.]+(?:[eE]-?[0-9]+)?$/) {
    $self->argh("invalid 'timeout' parameter");
  }
  $self->{_timeout} = abs $timeout;
  return $self;
}

=head2 C<next([ $time ])>

This method returns the time that this timer is next triggered after
the given time - or from now if the optional time parameter is not
given.

=cut

sub next {
  my $self = shift;
  my $t = shift;
  $t = Time::HiRes::time unless ($t);
  return $t + $self->{_timeout};
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

Copyright (C) 2006, 2008 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
