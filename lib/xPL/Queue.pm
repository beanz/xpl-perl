package xPL::Queue;

=head1 NAME

xPL::Queue - Perl extension for simple queue for use by xPL clients

=head1 SYNOPSIS

  use xPL::Queue qw/:all/;

  my $q = xPL::Queue->new();
  $q->enqueue('xxx');
  print $q->length,"\n";
  print $q->is_empty ? "empty" : "non-empty", "\n";
  my $elt = $q->dequeue();

=head1 DESCRIPTION

This module provides a simple queue abstraction for use by other modules.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use English qw/-no_match_vars/;
use Exporter;
use Time::HiRes;

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw(
                                  ) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision: 281 $/[1];

=head2 C<new()>

This method is the constructor.  It takes no arguments.

=cut

sub new {
  my $pkg = shift;
  my $self = { _q => [], _max_stats => 50, _stats => [], };
  bless $self, $pkg;
}

=head2 C<enqueue($item)>

This method adds an item to the queue.

=cut

sub enqueue {
  my ($self, $item) = @_;
  push @{$self->{_q}}, [ $item, Time::HiRes::time ];
  return scalar @{$self->{_q}};
}

=head2 C<dequeue()>

This method returns the oldest item from the queue or returns undef if
the queue contains no items.

=cut

sub dequeue {
  my $self = shift;
  my $rec = shift @{$self->{_q}};
  return unless (defined $rec);
  $self->_record_queue_time(Time::HiRes::time - $rec->[1]);
  return $rec->[0];
}

=head2 C<is_empty()>

This method returns true if the queue is empty.

=cut

sub is_empty {
  my $self = shift;
  return !scalar @{$self->{_q}};
}

=head2 C<length()>

This method returns the length of the queue.

=cut

sub length {
  my $self = shift;
  return scalar @{$self->{_q}};
}


=head2 C<average_queue_time()>

This method returns the average time that the most recently removed
items spent in the queue.  It returns undef if no items have been
removed from the queue since it was created.  By default 50 samples
are kept.

=cut

sub average_queue_time {
  my $self = shift;
  return unless (@{$self->{_stats}});
  my $sum = 0;
  foreach (@{$self->{_stats}}) {
    $sum += $_;
  }
  return $sum / scalar @{$self->{_stats}};
}

=head2 C<number_of_queue_time_samples()>

This method returns the number of queue time samples for dequeued
items that have been collected.

=cut

sub number_of_queue_time_samples {
  my $self = shift;
  return scalar @{$self->{_stats}};
}

=head2 C<_record_queue_time()>

This internal method is used to record a new queue time sample as a
item is removed from the queue.

=cut

sub _record_queue_time {
  my ($self, $delta) = @_;
  push @{$self->{_stats}}, $delta;
  shift @{$self->{_stats}} if (scalar @{$self->{_stats}} > $self->{_max_stats});
  return 1;
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

Copyright (C) 2008 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
