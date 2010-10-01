package xPL::Dock::Anomaly;

=head1 NAME

xPL::Dock::Anomaly - xPL::Dock plugin for anomaly reporting

=head1 SYNOPSIS

  use xPL::Dock qw/Anomaly/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This L<xPL::Dock> plugin adds anomaly reporting.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use Digest::SHA qw/sha1_hex/;
use Storable;
use Statistics::Basic qw/:all/;
use xPL::Dock::Plug;
use Time::HiRes;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  $self->{_path} = 'data';
  return
    (
     'anomaly-verbose+' => \$self->{_verbose},
     'anomaly-path=s' => \$self->{_path},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;
  my %p = @_;

  $self->SUPER::init($xpl, @_);

  $self->load_state;

  $xpl->add_xpl_callback(id => 'save_x10_handler',
                         filter => { schema => 'x10', class_type => 'basic' },
                         callback => sub { $self->save_x10_handler(@_) });

  $xpl->add_xpl_callback(id => 'save_sensor_handler',
                         filter => { schema => 'sensor' },
                         callback => sub { $self->save_sensor_handler(@_) });

  $xpl->add_xpl_callback(id => 'save_hbeat_handler',
                         filter => { message_type => 'xpl-stat',
                                     schema => 'hbeat' },
                         callback => sub { $self->save_hbeat_handler(@_) });

  $xpl->add_xpl_callback(id => 'save_config_handler',
                         filter => { message_type => 'xpl-stat',
                                     schema => 'config' },
                         callback => sub { $self->save_hbeat_handler(@_) });

  $xpl->add_timer(id => 'save_state',
                  timeout => 120,
                  callback => sub { $self->save_state });

  return $self;
}

sub save_hbeat_handler {
  my ($self, %p) = @_;
  my $msg = $p{message};
  my $t = Time::HiRes::time;
  $self->interval($msg->source.': hbeat', $t);
}

sub save_sensor_handler {
  my ($self, %p) = @_;
  my $msg = $p{message};
  my $t = Time::HiRes::time;
  my $units = $msg->field('units');
  $self->interval($msg->source.': sensor.basic '.
                      $msg->field('device').'['.
                      $msg->field('type').']'.
                      (defined $units ? $units : ''),
                  $t);
}

sub save_x10_handler {
  my ($self, %p) = @_;
  my $msg = $p{message};
  my $t = Time::HiRes::time;
  return 1 if ($msg->message_type eq 'xpl-cmnd');
  $self->interval($msg->source.': x10.basic '.$msg->field('device'), $t);
}

sub record {
  my ($self, $key) = @_;
  unless (exists $self->{_state}->{$key}) {
    print "New: ", $key, "\n";
    $self->{_state}->{$key} = {};
  }
  $self->{_state}->{$key}
}

sub interval {
  my ($self, $key, $t) = @_;
  my $rec = $self->record($key);
  my $last = $self->{_last}->{$key};
  if (defined $last) {
    my $interval = $t-$last;
    if ($interval > 0.05) {
      # we ignore message that arrive in a "batch"
      unless (exists $rec->{freq_v}) {
        $rec->{freq_v} = Statistics::Basic::Vector->new;
        $rec->{freq_v}->set_size(100);
      }
      my $comp = computed($rec->{freq_v});
      $comp->set_filter(sub { grep { $_ } @_ });
      my $mean = mean($comp);
      my $dev = stddev($comp);
      if (defined $mean->query && abs($interval - $mean) >= $dev*2) {
        print "Interval anomaly: ", $key, "\n";
        print "Interval: ", $interval, " avg=", $mean, " sd=", $dev, "\n";
        print "Vector: ", $comp, "\n";
      }
      $rec->{freq_v}->insert($interval);
    }
  }
  $self->{_last}->{$key} = $t;
  1;
}

sub load_state {
  my $self = shift;
  $self->{_state} = {};
  my $state;
  eval {
    $state = retrieve $self->{_path}.'/state.storable.bin';
  };
  unless ($@) {
    $self->{_state} = $state;
  }
  $self->{_state};
}

sub save_state {
  my $self = shift;
  my $old = $self->{_path}.'/state.storable.old';
  my $new = $self->{_path}.'/state.storable.bin';
  unlink $old;
  rename $old, $new;
  store $self->{_state}, $new;
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

xPL::Dock(3)

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2008, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
