package xPL::Dock::DawnDusk;

=head1 NAME

xPL::Dock::DawnDusk - xPL::Dock plugin for dawn and dusk reporting

=head1 SYNOPSIS

  use xPL::Dock qw/DawnDusk/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This L<xPL::Dock> plugin adds dawn and dusk reporting.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use xPL::Dock::Plug;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

__PACKAGE__->make_readonly_accessor($_) foreach (qw/latitude longitude
                                                    altitude iteration
                                                    state/);

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  $self->{_latitude} = 51;
  $self->{_longitude} = -1;
  $self->{_altitude} = undef;
  $self->{_iteration} = undef;
  return
    (
     'dawndusk-verbose+' => \$self->{_verbose},
     'dawndusk-latitude=s' => \$self->{_latitude},
     'dawndusk-longitude=s' => \$self->{_longitude},
     'dawndusk-altitude=s' => \$self->{_altitude},
     'dawndusk-iteration=s' => \$self->{_iteration},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;

  $self->SUPER::init($xpl, @_);

  my $args = 'latitude='.$self->{_latitude}.' longitude='.$self->{_longitude};
  $args .= ' altitude='.$self->{_altitude} if (defined $self->{_altitude});
  $args .= ' iteration='.$self->{_iteration} if (defined $self->{_iteration});

  # set up each new day at midnight
  $xpl->add_timer(id => 'dawn',
                  timeout => 'sunrise '.$args,
                  callback => sub { $self->dawn(); 1; });

  $xpl->add_timer(id => 'dusk',
                  timeout => 'sunset '.$args,
                  callback => sub { $self->dusk(); 1; });

  $self->{_state} =
    $xpl->timer_next('dusk') < $xpl->timer_next('dawn') ? 'day' : 'night';

  $xpl->add_xpl_callback(id => 'query_handler',
                         filter =>
                         {
                          message_type => 'xpl-cmnd',
                          schema => 'dawndusk.request',
                         },
                         callback => sub { $self->query_handler(@_) });
  return $self;
}

=head2 C<send_dawndusk( $status )>

This helper method sends a C<dawndusk.basic> C<xpl-trig> message with
the given status.

=cut

sub send_dawndusk {
  my ($self, $status) = @_;
  return $self->xpl->send(message_type => 'xpl-trig',
                          schema => 'dawndusk.basic',
                          body => [ type => 'dawndusk', status => $status ],
                         );
}

=head2 C<dawn( )>

This method is the callback for the dawn timer.

=cut

sub dawn {
  my $self = shift;
  $self->{_state} = 'day';
  $self->info("Dawn\n");
  $self->send_dawndusk('dawn');
  return 1;
}

=head2 C<dusk( )>

This method is the callback for the dusk timer.

=cut

sub dusk {
  my $self = shift;
  $self->{_state} = 'night';
  $self->info("Dusk\n");
  $self->send_dawndusk('dusk');
  return 1;
}

=head2 C<query_handler( %params )>

This method handles and responds to incoming C<dawndusk.request>
messages.

=cut

sub query_handler {
  my $self = shift;

  return $self->xpl->send(message_type => 'xpl-stat',
                          schema => 'dawndusk.basic',
                          body => [
                                   type => 'daynight',
                                   status => $self->{_state},
                                  ],
                         );
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
