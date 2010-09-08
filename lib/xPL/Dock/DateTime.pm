package xPL::Dock::DateTime;

=head1 NAME

xPL::Dock::DateTime - xPL::Dock plugin for date and time reporting

=head1 SYNOPSIS

  use xPL::Dock qw/DateTime/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This L<xPL::Dock> plugin adds date and time reporting.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use English qw/-no_match_vars/;
use POSIX qw/strftime/;
use xPL::Dock::Plug;

our @ISA = qw(xPL::Dock::Plug);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

__PACKAGE__->make_readonly_accessor($_) foreach (qw/interval/);

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  $self->{_interval} = 60;
  return
    (
     'datetime-verbose+' => \$self->{_verbose},
     'datetime-interval=i' => \$self->{_interval},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;
  my %p = @_;

  $self->SUPER::init($xpl, @_);

  my $timeout = $self->{_interval};
  if ($timeout ne '0') {
    $xpl->add_timer(id => 'datetime',
                    timeout => $timeout,
                    callback => sub { $self->datetime(); 1; });
  }

  $xpl->add_xpl_callback(id => 'query_handler',
                         filter =>
                         {
                          message_type => 'xpl-cmnd',
                          class => 'datetime.request',
                         },
                         callback => sub { $self->query_handler(@_) });
  return $self;
}

=head2 C<send_datetime( $status )>

This helper method sends a C<datetime.basic> C<xpl-trig> message with
the given status.

=cut

sub send_datetime {
  my ($self, $time) = @_;
  $time = time unless (defined $time);
  my $datetime = strftime "%Y%m%d%H%M%S", localtime $time;
  return $self->xpl->send(message_type => 'xpl-trig',
                          class => 'datetime.basic',
                          body =>
                          [
                           datetime => $datetime,
                           date => (substr $datetime, 0, 8, ''),
                           time => $datetime,
                           epoch => $time,
                          ],
                         );
}

=head2 C<datetime( )>

This method is the callback for the datetime timer.

=cut

sub datetime {
  my $self = shift;
  $self->send_datetime();
  return 1;
}

=head2 C<query_handler( %params )>

This method handles and responds to incoming C<datetime.request>
messages.

=cut

sub query_handler {
  my $self = shift;
  my %p = @_;
  my $msg = $p{message};
  my $peeraddr = $p{peeraddr};
  my $peerport = $p{peerport};

  my $time = time;
  my $datetime = strftime "%Y%m%d%H%M%S", localtime $time;
  return $self->xpl->send(message_type => 'xpl-stat',
                          class => 'datetime.basic',
                          body =>
                          [
                           status => $datetime,
                           epoch => $time,
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
