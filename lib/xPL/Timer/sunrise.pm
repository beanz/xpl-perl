package xPL::Timer::sunrise;

# $Id$

=head1 NAME

xPL::Timer::sunrise - Perl extension for xPL sunrise timer

=head1 SYNOPSIS

  use xPL::Timer;

  my $timer = xPL::Timer->new(type => 'sunrise',
                              latitude => 51, longitude => -1);

=head1 DESCRIPTION

This module creates an xPL timer abstraction for a sunrise timer.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use Time::HiRes;
use DateTime::Event::Sunrise;
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

=item latitude

The latitude in degrees - North is positive.  If this value is
ommitted, then the environment variable LATITUDE will be used.

=item longitude

The longitude in degrees - East is positive.  If this value is
ommitted, then the environment variable LONGITUDE will be used.

=item altitude

The sun altitude - default is -0.833.  See L<DateTime::Event::Sunrise(3pm)>
for more details.

=item altitude

The iteration - default is 0.  See L<DateTime::Event::Sunrise(3pm)>
for more details.

=item hours

Offset from the true value.  For instance, set to -1 will be an hour
before sunrise.

=item minutes

Offset from the true value.

=item seconds

Offset from the true value.

=item tz

The timezone to apply to the timer - Europe/London is assumed if this
value is omitted.

=back

=cut

sub init {
  my $self = shift;
  my $p = shift;
  exists $p->{latitude} or $p->{latitude} = $ENV{LATITUDE} or
    return $self->argh("requires 'latitude' parameter\n".
                       'or LATITUDE environment variable');
  exists $p->{longitude} or $p->{longitude} = $ENV{LONGITUDE} or
    return $self->argh("requires 'longitude' parameter\n".
                       'or LONGITUDE environment variable');
  exists $p->{altitude} or $p->{altitude} = -0.833;
  exists $p->{iteration} or $p->{iteration} = 0;

  my %args;
  foreach (qw/latitude longitude altitude iteration/) {
    $args{$_} = $p->{$_};
  }

  # the sunrise call will die on invalid parameters
  my $set = DateTime::Event::Sunrise->sunrise(%args);

  $self->{_set} = $set;

  my $offset;
  if (exists $p->{hours} or exists $p->{minutes} or exists $p->{seconds}) {
    $offset = {};
    foreach (qw/hours minutes seconds/) {
      next unless (exists $p->{$_});
      $offset->{$_} = $p->{$_};
    }
  }
  $self->{_offset} = $offset;
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
  if ($self->{_offset}) {
    my $dt=DateTime->from_epoch(epoch => $t)->subtract(%{$self->{_offset}});
    $self->{_set}->next($dt)->add(%{$self->{_offset}})->epoch;
  } else {
    my $dt=DateTime->from_epoch(epoch => $t);
    return $self->{_set}->next($dt)->epoch;
  }
}

1;
__END__

=head2 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
