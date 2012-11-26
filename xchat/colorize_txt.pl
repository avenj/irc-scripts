use strict; use warnings FATAL => 'all';
use Xchat;
use 5.12.1;
my $VERSION = '0.1';

## FIXME need command hook for managing color list
##  Also need save/load subs

my @reg = (
  'Channel Message',
  'Channel Action',
  'Channel Msg Hilight',
  'Channel Action Hilight',
#  'Your Message',
#  'Your Action',
);

my %nicks;
## FIXME hook to get color key names?
my %cl = qw/
  darkblue    18
  blue        28
  cyan        26
  brightcyan  27
  green       19
  brightgreen 25
  red         20
  darkred     21
  purple      22
  orange      23
  yellow      24
  magenta     29
  darkgray    30
  gray        31
  lightgray   16
/;

Xchat::register('ColorizeTxt', $VERSION, "Colorize text from users");

Xchat::print("o hai, colorizer thingo loaded");
hook_print($_, \&colorify,
  {
    data     => $_,
    priority => Xchat::PRI_HIGH,
  },
) for @reg;

hook_command( $_, \&cmd_colorify,
  {
    help_text => "Colorify/decolorify text from users",
  },
) for qw/colorify decolorify uncolorify/;

sub colorify {
  my $event = $_[1];

  my ($nick, $first) = @{ $_[0] };

  my $colorify = get_color_for(
    lc( $nick || return Xchat::EAT_NONE )
  );

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

  ## FIXME load %nicks list if none loaded yet
  ##  Map ANSI colors to names
  ##  Check maintained list, add appropriate ANSI color code
}

sub cmd_colorify {
  my ($cmd, @args) = @{ $_[0] };

  my $nick = lc($args[0] || '');

  ## FIXME load list if not already loaded

  unless ($nick) {
    ## FIXME if no $nick specified, print current list
    Xchat::print("Current colorifications:");
    Xchat::print($_)
      for map {; "$_ is $nicks{$_}" } keys %nicks;
    return Xchat::EAT_ALL
  }


  if ($nick eq '-colors') {
    ## FIXME print color key list
    return Xchat::EAT_ALL
  }

  if ($cmd eq 'colorify') {
    my $color = lc($args[1] || '');

    unless ($color && $cl{$color}) {
      Xchat::print("No color specified or no such color.");
      return Xchat::EAT_ALL
    }

    $nicks{$nick} = $color;
    ## FIXME call save

  } elsif ($cmd eq 'decolorify' || $cmd eq 'uncolorify') {

    unless (delete $nicks{$nick}) {
      Xchat::print("Do not have colorified nick $nick");
      return Xchat::EAT_ALL
    }

    ## FIXME call save

  } else {
    Xchat::print("what the fuck? fell through in cmd_colorify")
  }

  Xchat::EAT_ALL
}


__END__
