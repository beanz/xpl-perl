package xPL::Timer::recurrence;

=head1 NAME

xPL::Timer::recurrence - Perl extension for xPL recurrent timer

=head1 SYNOPSIS

  use xPL::Timer;

  my $timer = xPL::Timer->new(type => 'recurrence',
                              timeout => '5,15,25,35,35,55 * * * *');

=head1 DESCRIPTION

This module creates an xPL timer abstraction for a recurrent timer.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use Time::HiRes;
use DateTime::Event::Recurrence;
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

=item freq

This should be a valid L<DateTime::Event::Recurrence> method such
as C<daily>, C<hourly>, C<weekly>, etc.

=item tz

The timezone to apply to the timer - Europe/London is assumed if this
value is omitted.

=back

Any other arguments are passed directly to the L<DateTime::Event::Recurrence>
method.

=cut

sub init {
  my $self = shift;
  my $p = shift;
  exists $p->{freq} or $p->{freq} = 'hourly';
  my $method = $p->{freq};
  my $set;
  my %args = %{$p};
  delete $args{$_} foreach (qw/freq type tz verbose/);
  eval { $set = DateTime::Event::Recurrence->$method(%args); };
  $self->argh("freq='$method' is invalid: $@") unless ($set);
  $set->set_time_zone($p->{tz});
  $self->{_set} = $set;
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
  return $self->{_set}->next(DateTime->from_epoch(epoch => $t))->epoch;
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

Copyright (C) 2007, 2008 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
