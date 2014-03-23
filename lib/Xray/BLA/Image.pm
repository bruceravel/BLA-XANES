package Xray::BLA::Image;

use Moose;
use PDL::Lite;

has 'parent' => (is => 'rw', isa => 'Xray::BLA');
has 'image' =>  (is => 'rw', isa => 'PDL', default => sub {PDL::null});
# has 'image' => (
# 		metaclass => 'Collection::Array',
# 		is        => 'rw',
# 		isa       => 'ArrayRef[ArrayRef]',
# 		default   => sub { [] },
# 		provides  => {
# 			      'push'  => 'push_image',
# 			      'pop'   => 'pop_image',
# 			      'clear' => 'clear_image',
# 			     }
# 	       );

use constant BIT_DEPTH => 2**32;

sub Read {
  my ($self, $file) = @_;
  my @lol = ();
  my $img = $self->parent->read_image($file);
  foreach my $r (0 .. $self->parent->get_rows($img)-1) {
    my @row = $self->parent->get_row($img, $r);
    push @lol, \@row;
    #$self->push_image(\@row);
  };
  my $p = PDL->new(\@lol);
  ## this multiplication is faster done here with PDL than in X::B::Backend::Imager
  $p = $p * BIT_DEPTH;
  $self->image($p);
};


__PACKAGE__->meta->make_immutable;
1;
