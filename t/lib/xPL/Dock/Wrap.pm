package xPL::Dock::Wrap;
use base $ENV{XPL_PLUGIN_TO_WRAP};

sub new {
  my $pkg = shift;
  my $self = $pkg->SUPER::new(@_);
  $self->{_read_count} = 0;
  $self->{_reset_device} = 0;
  $self;
}

sub read {
  my $self = shift;
  $self->{_read_count}++;
  $self->SUPER::read(@_);
}

sub reset_device {
  my $self = shift;
  $self->{_reset_device}++;
  $self->SUPER::reset_device(@_);
}

1;
