package xPL::Dock::SMART;

=head1 NAME

xPL::Dock::SMART - xPL::Dock plugin for SMART disk temperature reporting.

=head1 SYNOPSIS

  use xPL::Dock qw/SMART/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This L<xPL::Dock> plugin adds SMART disk temperature reporting.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use AnyEvent::Util;
use xPL::Dock::Plug;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

__PACKAGE__->make_readonly_accessor($_) foreach (qw/interval devroot/);

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  $self->{_interval} = 120;
  $self->{_devroot} = '/dev';
  return
    (
     'smart-verbose+' => \$self->{_verbose},
     'smart-poll-interval=i' => \$self->{_interval},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;

  $self->SUPER::init($xpl, @_);

  # Add a timer to the xPL Client event loop to generate the
  # C<sensor.basic> messages.  The negative interval causes the timer to
  # trigger immediately rather than waiting for the first interval.
  $xpl->add_timer(id => 'smart',
                  timeout => -$self->interval,
                  callback => sub { $self->poll(); 1 });

  $self->{_buf} = '';
  $self->{_state} = {};

  return $self;
}

=head2 C<poll( )>

This method is the timer callback that polls the smart daemon.

=cut

sub poll {
  my $self = shift;
  my $root = $self->devroot;
  opendir my $dh, $root or die "Failed to open $root: $!\n";
  my @disks;
  foreach (readdir $dh) {
    next unless (/^sd.$/);
    my $dev = $root.'/'.$_;
    my %rec;
    my $cv =
      run_cmd [qw!sudo /usr/sbin/smartctl -i -A!, $dev],
        '>' => \$rec{output}, '<' => '/dev/null', '2>', \$rec{error};
    $cv->cb(sub { $self->read($cv, $dev, \%rec); });
  }
  return 1;
}

=head2 C<read( )>

This is the input callback that reads the data from the SMART devices
and sends appropriate C<sensor.basic> messages.

=cut

sub read {
  my ($self, $cv, $dev, $rec) = @_;
  if ($cv->recv) { # error?
    if ($self->verbose >= 2) {
      print STDERR "Errors:\n", $rec->{error}, "\n";
      print STDERR "Output:\n", $rec->{output}, "\n";
    }
    %{$rec} = ();
    undef $rec;
    return;
  }
  foreach (split /\n/, $rec->{output}) {
    if (/^Serial Number:\s+(\S+)\s*$/) {
      $rec->{sn} = $1;
    } elsif (/^194\s+Temperature_Celsius\s+(?:\S+\s+){7}([\d\.]+)/) {
      $rec->{C} = $1;
    }
  }
  return unless (exists $rec->{sn});
  my $device = $self->xpl->instance_id.'-disk-'.$rec->{sn};
  if (exists $rec->{C} && $rec->{C} !~ /[^\d\.]/) {
    $self->xpl->send_sensor_basic($device, 'temp', $rec->{C});
  }
  %{$rec} = ();
  undef $rec;
  return 1;
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

xPL::Dock(3), smartctl(8)

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2008, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
