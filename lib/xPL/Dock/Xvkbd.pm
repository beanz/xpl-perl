package xPL::Dock::Xvkbd;

=head1 NAME

xPL::Dock::Xvkbd - xPL::Dock plugin for a virtual keyboard application

=head1 SYNOPSIS

  use xPL::Dock qw/Xvkbd/;
  my $xpl = xPL::Dock->new();
  $xpl->main_loop();

=head1 DESCRIPTION

This L<xPL::Dock> plugin adds a virtual keyboard application.

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

=head2 C<getopts( )>

This method returns the L<Getopt::Long> option definition for the
plugin.

=cut

sub getopts {
  my $self = shift;
  return
    (
     'xvkbd-verbose+' => \$self->{_verbose},
    );
}

=head2 C<init(%params)>

=cut

sub init {
  my $self = shift;
  my $xpl = shift;
  my %p = @_;

  $self->SUPER::init($xpl, @_);

  $xpl->add_xpl_callback(id => 'xpl_handler',
                         filter =>
                         {
                          message_type => 'xpl-cmnd',
                          schema => 'remote.basic',
                         },
                         callback => sub { $self->xpl_handler(@_) });
  return $self;
}

=head2 C<xpl_handler( %params )>

This method handles and responds to incoming C<remote.basic> messages.

=cut

sub xpl_handler {
  my $self = shift;
  my %p = @_;
  my $msg = $p{message};
  my $peeraddr = $p{peeraddr};
  my $peerport = $p{peerport};

  my @cmd = qw/xvkbd -text/;
  push @cmd, $msg->field('keys');
  $self->info("Executing '@cmd'\n");
  system(@cmd);
  return 1;
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

xPL::Dock(3), xvkbd(1)

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2008, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
