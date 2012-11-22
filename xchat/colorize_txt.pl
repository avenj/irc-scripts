use strict; use warnings FATAL => 'all';
use Xchat;

my $VERSION = '0.1';

my @reg = (
  'Channel Message',
  'Channel Action',
  'Channel Msg Hilight',
  'Channel Action Hilight',
#  'Your Message',
#  'Your Action',
);

Xchat::register('ColorizeTxt', $VERSION, "Colorize text from users");

Xchat::print("o hai, colorizer thingo loaded");
hook_print($_, \&colorify,
  {
    data     => $_,
    priority => Xchat::PRI_HIGH,
  },
) for @reg;

sub colorify {
  my $event = $_[1];

  my ($nick, $first) = @{ $_[0] };

  my $colorify = get_color_for($nick);

  return Xchat::EAT_NONE
    if not defined $first
    or not $colorify
    or $first =~ /^\003/;

  my $last  = $_[0]->[-1];

  $_[0]->[1] = "\003" . $colorify . $first;
  $last .= "\003";

  Xchat::emit_print($event, @{ $_[0] });
  Xchat::EAT_ALL
}


sub get_color_for {
  my ($nick) = @_;

  ## FIXME maintain nick list
  ##  Map ANSI colors to names
  ##  Check maintained list, add appropriate ANSI color code
}

__END__
