package X::Osd;
sub new { bless { calls => [] }, 'X::Osd' }
sub calls { splice @{$_[0]->{calls}} }
sub AUTOLOAD {
  my $self = shift;
  our $AUTOLOAD;
  push @{$self->{calls}}, "$AUTOLOAD @_";
}
sub DESTROY {}
1;
