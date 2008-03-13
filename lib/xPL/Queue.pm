package xPL::Queue;

# $Id: Queue.pm 281 2007-06-15 16:53:50Z beanz $

=head1 NAME

xPL::Queue - Perl extension for xPL timer base class

=head1 SYNOPSIS

  use xPL::Queue qw/:all/;

  my $q = xPL::Queue->new();
  $q->enqueue('xxx');
  print $q->length,"\n";
  print $q->is_empty ? "empty" : "non-empty", "\n";
  my $elt = $q->dequeue();

=head1 DESCRIPTION

This module provides some simple utility functions for use by other
modules.

=head1 FUNCTIONS

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

sub new {
  my $pkg = shift;
  my $self = { _q => [], _max_stats => 50, _stats => [], };
  bless $self, $pkg;
}

sub enqueue {
  my ($self, $item) = @_;
  push @{$self->{_q}}, [ $item, Time::HiRes::time ];
  return scalar @{$self->{_q}};
}

sub dequeue {
  my $self = shift;
  my $rec = shift @{$self->{_q}};
  return undef unless (defined $rec);
  $self->_record_queue_time(Time::HiRes::time - $rec->[1]);
  return $rec->[0];
}

sub is_empty {
  my $self = shift;
  return !scalar @{$self->{_q}};
}

sub length {
  my $self = shift;
  return scalar @{$self->{_q}};
}

sub average_queue_time {
  my $self = shift;
  return undef unless (@{$self->{_stats}});
  my $sum = 0;
  foreach (@{$self->{_stats}}) {
    $sum += $_;
  }
  return $sum / scalar @{$self->{_stats}};
}

sub number_of_queue_time_samples {
  my $self = shift;
  return scalar @{$self->{_stats}};
}

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

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
