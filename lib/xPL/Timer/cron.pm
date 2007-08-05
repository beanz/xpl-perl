package xPL::Timer::cron;

# $Id$

=head1 NAME

xPL::Timer::cron - Perl extension for xPL cron-like timer

=head1 SYNOPSIS

  use xPL::Timer;

  my $timer = xPL::Timer->new(type => 'cron',
                              timeout => '5,15,25,35,35,55 * * * *');

=head1 DESCRIPTION

This module creates an xPL timer abstraction for a cron-like timer.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use Time::HiRes;
use DateTime::Event::Cron;
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

=item crontab

This should be a valid crontab-like string of the form
"minute hour day_of_month month day_of_week".

=item tz

The timezone to apply to the timer - Europe/London is assumed if this
value is omitted.

=back

=cut

sub init {
  my $self = shift;
  my $p = shift;
  exists $p->{tz} or $p->{tz} = $ENV{TZ} || 'Europe/London';
  my $set = DateTime::Event::Cron->from_cron($p->{crontab});
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

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
